/// Standard CMTAT - Full Feature Set with Native Coin<T> Architecture
/// Implements ERC-1404 compliance with transfer restriction codes
/// Uses capability-based access control and native IOTA Coin<T> with DenyList
module move_cmtat::standard_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list;

    use iota::clock::{Self, Clock};
    use iota::event;
    
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::validation;
    use move_cmtat::rule_engine;
    use move_cmtat::snapshot_engine;
    

    // ========== ONE-TIME WITNESS ==========
    public struct STANDARD_CMTAT has drop {}

    // ========== CMTAT REGISTRY (replaces base::TokenInfo) ==========
    public struct CMTATRegistry has key {
        id: object::UID,
        terms: String,
        information: String,
        token_id: String,
        document_uri: String,
        deactivated: bool,
    }

    // ========== ENGINES ==========
    public struct StandardCMTATState has key {
        id: object::UID,
        rule_engine: rule_engine::RuleEngine,
        snapshot_engine: snapshot_engine::SnapshotEngine,
    }

    // ========== COMPLIANCE STATE ==========
    public struct ComplianceState has key {
        id: object::UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
    }

    // ========== CAPABILITIES ==========
    public struct AdminCap has key, store { id: object::UID }
    public struct MintCap has key, store { id: object::UID }
    public struct BurnCap has key, store { id: object::UID }
    public struct FreezeCap has key, store { id: object::UID }
    public struct PauseCap has key, store { id: object::UID }
    public struct SnapshotCap has key, store { id: object::UID }
    public struct EnforcerCap has key, store { id: object::UID }

    // ========== EVENTS ==========
    public struct TokenMinted has copy, drop {
        minter: address,
        to: address,
        amount: u64,
    }

    public struct TokenBurned has copy, drop {
        burner: address,
        from: address,
        amount: u64,
    }

    // ========== ERRORS ==========
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    

    // ========== INIT FUNCTION ==========
    fun init(witness: STANDARD_CMTAT, ctx: &mut tx_context::TxContext) {
        // Create native regulated currency with DenyList integration
        let (treasury_cap, deny_cap, coin_metadata) = coin::create_regulated_currency_v1(
            witness,
            9,                                          // decimals
            b"STCMTAT",                                // symbol
            b"Standard CMTAT Token",                   // name
            b"CMTAT Standard with full compliance",    // description
            option::none(),                             // icon_url
            true,                                       // allow global pause
            ctx
        );

        // Create CMTAT-specific registry
        let registry = CMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            document_uri: string::utf8(b""),
            deactivated: false,
        };

        // Create state with engines
        let state = StandardCMTATState {
            id: object::new(ctx),
            rule_engine: rule_engine::init_rule_engine(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
        };

        // Create compliance state
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
        };

        // Create capability objects
        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };

        // Transfer TreasuryCap and DenyCapV1 to deployer
        transfer::public_transfer(treasury_cap, deployer);
        transfer::public_transfer(deny_cap, deployer);
        
        // Freeze CoinMetadata (immutable)
        transfer::public_freeze_object(coin_metadata);
        
        // Share registry and states
        transfer::share_object(registry);
        transfer::share_object(state);
        transfer::share_object(compliance_state);

        // Transfer capabilities to deployer
        transfer::transfer(admin_cap, deployer);
        transfer::transfer(mint_cap, deployer);
        transfer::transfer(burn_cap, deployer);
        transfer::transfer(freeze_cap, deployer);
        transfer::transfer(pause_cap, deployer);
        transfer::transfer(snapshot_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
    }

    // ========== VIEW FUNCTIONS (Native CoinMetadata) ==========
    public fun name(metadata: &CoinMetadata<STANDARD_CMTAT>): String {
        coin::get_name(metadata)
    }

    public fun symbol(metadata: &CoinMetadata<STANDARD_CMTAT>): String {
        string::from_ascii(coin::get_symbol(metadata))
    }

    public fun decimals(metadata: &CoinMetadata<STANDARD_CMTAT>): u8 {
        coin::get_decimals(metadata)
    }

    public fun total_supply(treasury_cap: &TreasuryCap<STANDARD_CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    // ========== CMTAT REGISTRY VIEWS ==========
    public fun terms(registry: &CMTATRegistry): String { registry.terms }
    public fun information(registry: &CMTATRegistry): String { registry.information }
    public fun token_id(registry: &CMTATRegistry): String { registry.token_id }
    public fun document_uri(registry: &CMTATRegistry): String { registry.document_uri }
    public fun deactivated(registry: &CMTATRegistry): bool { registry.deactivated }

    // ========== COMPLIANCE VIEWS ==========
    public fun paused(compliance_state: &ComplianceState): bool {
        pause::is_paused(&compliance_state.pause_state)
    }

    public fun is_frozen(compliance_state: &ComplianceState, account: address): bool {
        freeze::is_frozen(&compliance_state.freeze_state, account)
    }

    public fun is_paused_native(deny_list: &deny_list::DenyList, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<STANDARD_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen_native(deny_list: &deny_list::DenyList, account: address, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<STANDARD_CMTAT>(deny_list, account, ctx)
    }

    // ========== ERC-1404 TRANSFER VALIDATION ==========
    public fun detect_transfer_restriction(
        compliance_state: &ComplianceState,
        from: address,
        to: address,
        amount: u64,
        from_balance: u64
    ): u8 {
        rule_engine::validate_transfer(
            &compliance_state.pause_state,
            &compliance_state.freeze_state,
            from,
            to,
            amount,
            from_balance
        )
    }

    public fun message_for_transfer_restriction(code: u8): String {
        validation::get_restriction_message(code)
    }

    // ========== ADMINISTRATIVE FUNCTIONS ==========
    public entry fun set_terms(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_terms: String
    ) {
        registry.terms = new_terms;
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_info: String
    ) {
        registry.information = new_info;
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_id: String
    ) {
        registry.token_id = new_id;
    }

    public entry fun set_document_uri(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        uri: String
    ) {
        registry.document_uri = uri;
    }

    // ========== MINTING FUNCTIONS (Native Coin<T>) ==========
    public fun mint(
        _mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ): Coin<STANDARD_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);
        
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);

        let coins = coin::mint(treasury_cap, amount, ctx);

        event::emit(TokenMinted {
            minter: tx_context::sender(ctx),
            to,
            amount,
        });

        coins
    }

    public entry fun mint_and_transfer(
        mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ) {
        let coins = mint(mint_cap, treasury_cap, registry, compliance_state, deny_list, to, amount, ctx);
        transfer::public_transfer(coins, to);
    }

    // ========== BURNING FUNCTIONS (Native Coin<T>) ==========
    public fun burn(
        treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
        coins: Coin<STANDARD_CMTAT>,
        ctx: &tx_context::TxContext
    ) {
        let amount = coin::value(&coins);
        let burner = tx_context::sender(ctx);

        coin::burn(treasury_cap, coins);

        event::emit(TokenBurned {
            burner,
            from: burner,
            amount,
        });
    }

    public entry fun burn_entry(
        treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
        coins: Coin<STANDARD_CMTAT>,
        compliance_state: &ComplianceState,
        ctx: &tx_context::TxContext
    ) {
        pause::require_not_paused(&compliance_state.pause_state);
        burn(treasury_cap, coins, ctx);
    }

    // ========== PAUSE FUNCTIONS ==========
    public entry fun pause(
        _pause_cap: &PauseCap,
        compliance_state: &mut ComplianceState
    ) {
        pause::pause(&mut compliance_state.pause_state);
    }

    public entry fun unpause(
        _pause_cap: &PauseCap,
        compliance_state: &mut ComplianceState
    ) {
        pause::unpause(&mut compliance_state.pause_state);
    }

    public entry fun pause_native(
        _pause_cap: &PauseCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);
    }

    public entry fun unpause_native(
        _pause_cap: &PauseCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_disable_global_pause(deny_list, deny_cap, ctx);
    }

    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        compliance_state: &mut ComplianceState
    ) {
        registry.deactivated = true;
        pause::deactivate(&mut compliance_state.pause_state);
    }

    // ========== FREEZE FUNCTIONS ==========
    public entry fun set_address_frozen(
        _freeze_cap: &FreezeCap,
        compliance_state: &mut ComplianceState,
        account: address,
        frozen: bool
    ) {
        freeze::set_address_frozen(&mut compliance_state.freeze_state, account, frozen);
    }

    public entry fun set_address_frozen_native(
        _enforcer_cap: &EnforcerCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        account: address,
        frozen: bool,
        ctx: &mut tx_context::TxContext
    ) {
        if (frozen) {
            coin::deny_list_v1_add(deny_list, deny_cap, account, ctx);
        } else {
            coin::deny_list_v1_remove(deny_list, deny_cap, account, ctx);
        }
    }

    public entry fun freeze_partial_tokens(
        _freeze_cap: &FreezeCap,
        compliance_state: &mut ComplianceState,
        account: address,
        amount: u64
    ) {
        freeze::freeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
    }

    public entry fun unfreeze_partial_tokens(
        _freeze_cap: &FreezeCap,
        compliance_state: &mut ComplianceState,
        account: address,
        amount: u64
    ) {
        freeze::unfreeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
    }

    // ========== SNAPSHOT FUNCTIONS ==========
    public entry fun schedule_snapshot(
        _snapshot_cap: &SnapshotCap,
        state: &mut StandardCMTATState,
        treasury_cap: &TreasuryCap<STANDARD_CMTAT>,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = coin::total_supply(treasury_cap);
        snapshot_engine::create_snapshot(&mut state.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ========== TRANSFER FUNCTIONS WITH VALIDATION ==========
    public entry fun transfer(
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        coins: Coin<STANDARD_CMTAT>,
        to: address,
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = coin::value(&coins);
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);

        let restriction_code = rule_engine::validate_transfer(
            &compliance_state.pause_state,
            &compliance_state.freeze_state,
            from,
            to,
            amount,
            amount
        );

        rule_engine::require_valid_transfer(restriction_code);
        transfer::public_transfer(coins, to);
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(STANDARD_CMTAT {}, ctx);
    }
}
