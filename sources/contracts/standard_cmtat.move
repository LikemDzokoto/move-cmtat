/// Standard CMTAT - Full Feature Set with Native Coin<T> Architecture
/// Implements CMTAT compliant transfer restriction validation
/// Uses capability-based access control and native IOTA Coin<T> with DenyList
module move_cmtat::standard_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list;

    use iota::clock::{Self, Clock};
    use iota::event;

    use move_cmtat::rule_engine_v2;
    use move_cmtat::snapshot_engine;


    // ========== ONE-TIME WITNESS ==========
    public struct STANDARD_CMTAT has drop {}

    // ========== CMTAT REGISTRY  ==========
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
        snapshot_engine: snapshot_engine::SnapshotEngine,
    }

    // ========== CAPABILITIES ==========
    public struct AdminCap has key, store { id: object::UID }
    public struct MintCap has key, store { id: object::UID }
    public struct BurnCap has key, store { id: object::UID }
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

    public struct AddressFrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct AddressUnfrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct ModulePaused has copy, drop {
        pauser: address,
    }

    public struct ModuleUnpaused has copy, drop {
        pauser: address,
    }

    public struct ModuleDeactivated has copy, drop {
        admin: address,
    }

    public struct TermsUpdated has copy, drop {
        admin: address,
        new_terms: String,
    }

    public struct InformationUpdated has copy, drop {
        admin: address,
        new_information: String,
    }

    public struct TokenIdUpdated has copy, drop {
        admin: address,
        new_token_id: String,
    }

    public struct DocumentUriUpdated has copy, drop {
        admin: address,
        new_document_uri: String,
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
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
        };

        // Create capability objects
        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
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

        // Transfer capabilities to deployer
        transfer::transfer(admin_cap, deployer);
        transfer::transfer(mint_cap, deployer);
        transfer::transfer(burn_cap, deployer);
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

    // ========== COMPLIANCE VIEWS (Native DenyList) ==========
    public fun is_paused(deny_list: &deny_list::DenyList, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<STANDARD_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen(deny_list: &deny_list::DenyList, account: address, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<STANDARD_CMTAT>(deny_list, account, ctx)
    }

    // ========== CMTAT TRANSFER RESTRICTION VALIDATION ==========
    public fun message_for_transfer_restriction(code: u8): String {
        rule_engine_v2::message_for_restriction_code(code)
    }

    // ========== CAPABILITY GRANTING ==========
    // Note: Grant functions transfer TreasuryCap/DenyCap to enable EVM-like behavior
    public entry fun grant_minter(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<STANDARD_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let mint_cap = MintCap { id: object::new(ctx) };
        transfer::transfer(mint_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_burner(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<STANDARD_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let burn_cap = BurnCap { id: object::new(ctx) };
        transfer::transfer(burn_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_pauser(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<STANDARD_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let pause_cap = PauseCap { id: object::new(ctx) };
        transfer::transfer(pause_cap, to);
        transfer::public_transfer(deny_cap, to);
    }

    public entry fun grant_enforcer(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<STANDARD_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };
        transfer::transfer(enforcer_cap, to);
        transfer::public_transfer(deny_cap, to);
    }

    public entry fun grant_snapshooter(
        _admin_cap: &AdminCap,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        transfer::transfer(snapshot_cap, to);
    }

    // ========== ADMINISTRATIVE FUNCTIONS ==========
    public entry fun set_terms(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_terms: String,
        ctx: &mut tx_context::TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.terms = new_terms;

        event::emit(TermsUpdated {
            admin,
            new_terms,
        });
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_info: String,
        ctx: &mut tx_context::TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.information = new_info;

        event::emit(InformationUpdated {
            admin,
            new_information: new_info,
        });
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_id: String,
        ctx: &mut tx_context::TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.token_id = new_id;

        event::emit(TokenIdUpdated {
            admin,
            new_token_id: new_id,
        });
    }

    public entry fun set_document_uri(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        uri: String,
        ctx: &mut tx_context::TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.document_uri = uri;

        event::emit(DocumentUriUpdated {
            admin,
            new_document_uri: uri,
        });
    }

    // ========== MINTING FUNCTIONS (Native Coin<T>) ==========
    public fun mint(
        _mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ): Coin<STANDARD_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);

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
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ) {
        let coins = mint(mint_cap, treasury_cap, registry, deny_list, to, amount, ctx);
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
        deny_list: &deny_list::DenyList,
        ctx: &tx_context::TxContext
    ) {
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        burn(treasury_cap, coins, ctx);
    }

    // ========== PAUSE FUNCTIONS (Native DenyList) ==========
    public entry fun pause(
        _pause_cap: &PauseCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModulePaused {
            pauser: tx_context::sender(ctx),
        });
    }

    public entry fun unpause(
        _pause_cap: &PauseCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_disable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleUnpaused {
            pauser: tx_context::sender(ctx),
        });
    }

    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        ctx: &mut tx_context::TxContext
    ) {
        registry.deactivated = true;
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleDeactivated {
            admin: tx_context::sender(ctx),
        });
    }

    // ========== FREEZE FUNCTIONS (Native DenyList) ==========
    public entry fun set_address_frozen(
        _enforcer_cap: &EnforcerCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        account: address,
        frozen: bool,
        ctx: &mut tx_context::TxContext
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

    public entry fun batch_set_address_frozen(
        enforcer_cap: &EnforcerCap,
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<STANDARD_CMTAT>,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &mut tx_context::TxContext
    ) {
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), 0);

        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);

            set_address_frozen(enforcer_cap, deny_list, deny_cap, account, status, ctx);

            i = i + 1;
        }
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
        deny_list: &deny_list::DenyList,
        coins: Coin<STANDARD_CMTAT>,
        to: address,
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);

        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);

        transfer::public_transfer(coins, to);
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(STANDARD_CMTAT {}, ctx);
    }
}
