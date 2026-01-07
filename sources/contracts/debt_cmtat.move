/// Debt CMTAT - Native Coin<T> for Debt Securities
/// Specialized for corporate bonds and debt instruments
/// Implements debt-specific controls with native DenyList
module move_cmtat::debt_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::clock::{Self, Clock};
    use iota::event;
    
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::debt;
    use move_cmtat::rule_engine;
    use move_cmtat::snapshot_engine;
    use move_cmtat::icmtat;

    // ========== ONE-TIME WITNESS ==========
    public struct DEBT_CMTAT has drop {}

    // ========== CMTAT REGISTRY ==========
    public struct CMTATRegistry has key {
        id: UID,
        terms: String,
        information: String,
        token_id: String,
        document_uri: String,
        deactivated: bool,
    }

    // ========== STATE WITH SNAPSHOT ENGINE ==========
    public struct DebtCMTATState has key {
        id: UID,
        snapshot_engine: snapshot_engine::SnapshotEngine,
    }

    // ========== COMPLIANCE STATE (includes debt) ==========
    public struct ComplianceState has key {
        id: UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        debt_state: debt::DebtState,
    }

    // ========== CAPABILITIES ==========
    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct FreezeCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }
    public struct SnapshotCap has key, store { id: UID }
    public struct DebtCap has key, store { id: UID }
    public struct EnforcerCap has key, store { id: UID }

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

    public struct AddressFrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct AddressUnfrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct DebtFlagged has copy, drop {
        debt_cap_holder: address,
    }

    // ========== ERRORS ==========
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    const ETransferRestricted: u64 = 3;
    const EDebtInDefault: u64 = 4;

    // ========== INIT FUNCTION ==========
    fun init(witness: DEBT_CMTAT, ctx: &mut TxContext) {
        // Create native regulated currency with DenyList
        let (treasury_cap, deny_cap, coin_metadata) = coin::create_regulated_currency_v1(
            witness,
            9,
            b"DTCMTAT",
            b"Debt CMTAT Token",
            b"CMTAT for debt securities (bonds)",
            option::none(),
            true,
            ctx
        );

        // Create CMTAT registry
        let registry = CMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            document_uri: string::utf8(b""),
            deactivated: false,
        };

        // Create state with snapshot engine
        let state = DebtCMTATState {
            id: object::new(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
        };

        // Create compliance state with debt state
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
            debt_state: debt::init_debt_state(ctx),
        };

        // Create capabilities
        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        let debt_cap = DebtCap { id: object::new(ctx) };
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };

        // Transfer and freeze objects
        transfer::public_transfer(treasury_cap, deployer);
        transfer::public_transfer(deny_cap, deployer);
        transfer::public_freeze_object(coin_metadata);
        
        transfer::share_object(registry);
        transfer::share_object(state);
        transfer::share_object(compliance_state);

        transfer::transfer(admin_cap, deployer);
        transfer::transfer(mint_cap, deployer);
        transfer::transfer(burn_cap, deployer);
        transfer::transfer(freeze_cap, deployer);
        transfer::transfer(pause_cap, deployer);
        transfer::transfer(snapshot_cap, deployer);
        transfer::transfer(debt_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
    }

    // ========== VIEW FUNCTIONS (Native CoinMetadata) ==========
    public fun name(metadata: &CoinMetadata<DEBT_CMTAT>): String {
        coin::get_name(metadata)
    }

    public fun symbol(metadata: &CoinMetadata<DEBT_CMTAT>): String {
        string::from_ascii(coin::get_symbol(metadata))
    }

    public fun decimals(metadata: &CoinMetadata<DEBT_CMTAT>): u8 {
        coin::get_decimals(metadata)
    }

    public fun total_supply(treasury_cap: &TreasuryCap<DEBT_CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    // ========== REGISTRY VIEWS ==========
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

    public fun debt(compliance_state: &ComplianceState): String {
        debt::get_debt(&compliance_state.debt_state)
    }

    public fun credit_events(compliance_state: &ComplianceState): String {
        debt::get_credit_events(&compliance_state.debt_state)
    }

    public fun debt_engine(compliance_state: &ComplianceState): address {
        debt::get_debt_engine(&compliance_state.debt_state)
    }

    public fun is_default_flagged(compliance_state: &ComplianceState): bool {
        debt::is_default_flagged(&compliance_state.debt_state)
    }

    public fun is_paused_native(deny_list: &DenyList, ctx: &TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<DEBT_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen_native(deny_list: &DenyList, account: address, ctx: &TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<DEBT_CMTAT>(deny_list, account, ctx)
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

    // ========== DEBT-SPECIFIC FUNCTIONS ==========
    public entry fun set_debt(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        debt_info: String
    ) {
        debt::set_debt(&mut compliance_state.debt_state, debt_info);
    }

    public entry fun set_credit_events(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        events: String
    ) {
        debt::set_credit_events(&mut compliance_state.debt_state, events);
    }

    public entry fun set_debt_engine(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        engine: address
    ) {
        debt::set_debt_engine(&mut compliance_state.debt_state, engine);
    }

    public entry fun flag_default(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        ctx: &TxContext
    ) {
        debt::flag_default(&mut compliance_state.debt_state);
        
        event::emit(DebtFlagged {
            debt_cap_holder: tx_context::sender(ctx),
        });
    }

    // ========== MINTING FUNCTIONS (Native Coin<T>) ==========
    public fun mint(
        _mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<DEBT_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);
        
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);
        debt::require_not_in_default(&compliance_state.debt_state);

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
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coins = mint(mint_cap, treasury_cap, registry, compliance_state, deny_list, to, amount, ctx);
        transfer::public_transfer(coins, to);
    }

    // ========== BURNING FUNCTIONS (Native Coin<T>) ==========
    public fun burn(
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        coins: Coin<DEBT_CMTAT>,
        ctx: &TxContext
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
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        coins: Coin<DEBT_CMTAT>,
        compliance_state: &ComplianceState,
        ctx: &TxContext
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
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);
    }

    public entry fun unpause_native(
        _pause_cap: &PauseCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut TxContext
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
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
        account: address,
        frozen: bool,
        ctx: &mut TxContext
    ) {
        let enforcer = tx_context::sender(ctx);

        if (frozen) {
            coin::deny_list_v1_add(deny_list, deny_cap, account, ctx);
            event::emit(AddressFrozen { enforcer, account });
        } else {
            coin::deny_list_v1_remove(deny_list, deny_cap, account, ctx);
            event::emit(AddressUnfrozen { enforcer, account });
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
        state: &mut DebtCMTATState,
        treasury_cap: &TreasuryCap<DEBT_CMTAT>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = coin::total_supply(treasury_cap);

        snapshot_engine::create_snapshot(&mut state.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ========== TRANSFER FUNCTIONS WITH VALIDATION ==========
    public entry fun transfer(
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        coins: Coin<DEBT_CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = coin::value(&coins);

        // Check deactivation
        assert!(!registry.deactivated, EModuleDeactivated);

        // Check debt default status
        assert!(!is_default_flagged(compliance_state), EDebtInDefault);

        // Check native DenyList
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);

        // Validate transfer using rule engine
        let restriction_code = rule_engine::validate_transfer(
            &compliance_state.pause_state,
            &compliance_state.freeze_state,
            from,
            to,
            amount,
            amount
        );

        assert!(restriction_code == icmtat::restriction_code_valid(), ETransferRestricted);

        // Transfer the coins
        transfer::public_transfer(coins, to);
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(DEBT_CMTAT {}, ctx);
    }
}
