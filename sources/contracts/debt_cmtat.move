/// Debt CMTAT - Native Coin<T> for Debt Securities
/// Specialized for corporate bonds and debt instruments
/// Implements debt-specific controls 
module move_cmtat::debt_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list;

    use iota::clock::{Self, Clock};
    use iota::event;

    use move_cmtat::debt;
    use move_cmtat::snapshot_engine;
    use move_cmtat::rule_engine_v2;


    public struct DEBT_CMTAT has drop {}

    // ========== CMTAT REGISTRY ==========
    public struct CMTATRegistry has key {
        id: object::UID,
        terms: String,
        information: String,
        token_id: String,
        document_uri: String,
        deactivated: bool,
    }

    // ========== STATE WITH SNAPSHOT ENGINE ==========
    public struct DebtCMTATState has key {
        id: object::UID,
        snapshot_engine: snapshot_engine::SnapshotEngine,
        rule_engine: rule_engine_v2::RuleEngine,
        rule_engine_active: bool,
    }


    public struct ComplianceState has key {
        id: object::UID,
        debt_state: debt::DebtState,
    }

   
    public struct AdminCap has key, store { id: object::UID }
    public struct MintCap has key, store { id: object::UID }
    public struct BurnCap has key, store { id: object::UID }
    public struct PauseCap has key, store { id: object::UID }
    public struct SnapshotCap has key, store { id: object::UID }
    public struct DebtCap has key, store { id: object::UID }
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

    public struct DebtFlagged has copy, drop {
        debt_cap_holder: address,
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

    public struct DebtUpdated has copy, drop {
        debt_manager: address,
    }

    public struct CreditEventsUpdated has copy, drop {
        debt_manager: address,
    }

    public struct DebtEngineUpdated has copy, drop {
        debt_manager: address,
        engine: address,
    }

    public struct RuleEngineRemoved has copy, drop {
        admin: address,
    }

    public struct RuleEngineRestored has copy, drop {
        admin: address,
    }

    // ========== ERRORS ==========
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    const EDebtInDefault: u64 = 4;
    const ERuleEngineNotActive: u64 = 5;
    const ERuleEngineAlreadyActive: u64 = 6;


    fun init(witness: DEBT_CMTAT, ctx: &mut tx_context::TxContext) {
        
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

      
        let registry = CMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            document_uri: string::utf8(b""),
            deactivated: false,
        };

        // state with snapshot engine and rule engine
        let state = DebtCMTATState {    
            id: object::new(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
            rule_engine: rule_engine_v2::init_rule_engine_v2(ctx),
            rule_engine_active: true,
        };

        //  compliance state with debt state only
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            debt_state: debt::init_debt_state(ctx),
        };

        // capabilities creation
        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
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
        transfer::transfer(pause_cap, deployer);
        transfer::transfer(snapshot_cap, deployer);
        transfer::transfer(debt_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
    }

    // ========== VIEW FUNCTIONS  ==========
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

    // ========== COMPLIANCE VIEWS  ==========
    public fun is_paused(deny_list: &deny_list::DenyList, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<DEBT_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen(deny_list: &deny_list::DenyList, account: address, ctx: &tx_context::TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<DEBT_CMTAT>(deny_list, account, ctx)
    }

    // ========== DEBT-SPECIFIC VIEWS ==========
    public fun debt(compliance_state: &ComplianceState): String {
        debt::get_debt(&compliance_state.debt_state)
    }

    public fun credit_events(compliance_state: &ComplianceState): debt::CreditEvents {
        debt::get_credit_events(&compliance_state.debt_state)
    }

    public fun debt_engine(compliance_state: &ComplianceState): address {
        debt::get_debt_engine(&compliance_state.debt_state)
    }

    public fun is_default_flagged(compliance_state: &ComplianceState): bool {
        debt::is_default_flagged(&compliance_state.debt_state)
    }

    // ========== CAPABILITY GRANTING ==========

    public entry fun grant_minter(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<DEBT_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let mint_cap = MintCap { id: object::new(ctx) };
        transfer::transfer(mint_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_burner(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<DEBT_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let burn_cap = BurnCap { id: object::new(ctx) };
        transfer::transfer(burn_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_pauser(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<DEBT_CMTAT>,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let pause_cap = PauseCap { id: object::new(ctx) };
        transfer::transfer(pause_cap, to);
        transfer::public_transfer(deny_cap, to);
    }

    public entry fun grant_enforcer(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<DEBT_CMTAT>,
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

    public entry fun grant_debt_manager(
        _admin_cap: &AdminCap,
        debt_cap: DebtCap,
        to: address,
        ctx: &mut tx_context::TxContext
    ) {
        let new_debt_cap = DebtCap { id: object::new(ctx) };
        transfer::transfer(new_debt_cap, to);
        transfer::public_transfer(debt_cap, to);
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

    // ========== DEBT-SPECIFIC FUNCTIONS ==========
    public entry fun set_debt(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        debt_info: String,
        ctx: &tx_context::TxContext
    ) {
        debt::set_debt(&mut compliance_state.debt_state, debt_info);

        event::emit(DebtUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun set_credit_events(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        flag_default: bool,
        flag_redeemed: bool,
        flag_matured: bool,
        rating: String,
        principal_distributed: u64,
        next_coupon_date: u64,
        ctx: &tx_context::TxContext
    ) {
        let credit_events = debt::create_credit_events(
            flag_default,
            flag_redeemed,
            flag_matured,
            rating,
            principal_distributed,
            next_coupon_date,
        );
        debt::set_credit_events(&mut compliance_state.debt_state, credit_events);

        event::emit(CreditEventsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun set_debt_engine(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        engine: address,
        ctx: &tx_context::TxContext
    ) {
        debt::set_debt_engine(&mut compliance_state.debt_state, engine);

        event::emit(DebtEngineUpdated {
            debt_manager: tx_context::sender(ctx),
            engine,
        });
    }

    public entry fun flag_default(
        _debt_cap: &DebtCap,
        compliance_state: &mut ComplianceState,
        ctx: &tx_context::TxContext
    ) {
        debt::flag_default(&mut compliance_state.debt_state);

        event::emit(DebtFlagged {
            debt_cap_holder: tx_context::sender(ctx),
        });
    }

    // ========== MINTING FUNCTIONS  ==========
    public fun mint(
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ): Coin<DEBT_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);
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
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        state: &mut DebtCMTATState,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        clock: &Clock,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ) {
        // RuleEngine validation for mint (if active)
        if (state.rule_engine_active) {
            let is_to_vip = rule_engine_v2::is_vip(&state.rule_engine, to);
            rule_engine_v2::require_valid_transfer(
                &state.rule_engine,
                tx_context::sender(ctx),
                to,
                amount,
                clock,
                is_to_vip,
                0 // No balance check for mint
            );
        };

        let coins = mint(treasury_cap, registry, compliance_state, deny_list, to, amount, ctx);
        transfer::public_transfer(coins, to);
    }

    // ========== BURNING FUNCTIONS  ==========
    public fun burn(
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        coins: Coin<DEBT_CMTAT>,
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
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        coins: Coin<DEBT_CMTAT>,
        deny_list: &deny_list::DenyList,
        ctx: &tx_context::TxContext
    ) {
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        burn(treasury_cap, coins, ctx);
    }

    // ========== PAUSE FUNCTIONS  ==========
    public entry fun pause(
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
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
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
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
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
        ctx: &mut tx_context::TxContext
    ) {
        registry.deactivated = true;
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleDeactivated {
            admin: tx_context::sender(ctx),
        });
    }

    // ========== FREEZE FUNCTIONS  ==========
    public entry fun set_address_frozen(
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
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
        deny_list: &mut deny_list::DenyList,
        deny_cap: &mut DenyCapV1<DEBT_CMTAT>,
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

            set_address_frozen(deny_list, deny_cap, account, status, ctx);

            i = i + 1;
        }
    }

    // ========== SNAPSHOT FUNCTIONS ==========
    public entry fun schedule_snapshot(
        _snapshot_cap: &SnapshotCap,
        state: &mut DebtCMTATState,
        treasury_cap: &TreasuryCap<DEBT_CMTAT>,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = coin::total_supply(treasury_cap);

        snapshot_engine::create_snapshot(&mut state.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ========== RULE ENGINE MANAGEMENT ==========
    public fun rule_engine_active(state: &DebtCMTATState): bool {
        state.rule_engine_active
    }

    public fun is_vip(state: &DebtCMTATState, account: address): bool {
        rule_engine_v2::is_vip(&state.rule_engine, account)
    }

    public fun is_rule_enabled(state: &DebtCMTATState, rule_type: u8): bool {
        rule_engine_v2::is_rule_enabled(&state.rule_engine, rule_type)
    }

    public entry fun add_rule(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        rule_type: u8,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::add_rule(&mut state.rule_engine, rule_type, ctx);
    }

    public entry fun remove_rule(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        rule_type: u8,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::remove_rule(&mut state.rule_engine, rule_type, ctx);
    }

    public entry fun add_vip(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::add_vip(&mut state.rule_engine, account, ctx);
    }

    public entry fun remove_vip(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::remove_vip(&mut state.rule_engine, account, ctx);
    }

    public entry fun set_auto_approval(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        enabled: bool,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::set_auto_approval(&mut state.rule_engine, enabled, ctx);
    }

    public entry fun set_time_limits(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        approval_deadline_ms: u64,
        execution_deadline_ms: u64,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::set_time_limits(&mut state.rule_engine, approval_deadline_ms, execution_deadline_ms, ctx);
    }

    // ========== RULE MANAGEMENT ==========

    public entry fun add_to_blacklist(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::add_to_blacklist(&mut state.rule_engine, account, ctx);
    }

    public entry fun remove_from_blacklist(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::remove_from_blacklist(&mut state.rule_engine, account, ctx);
    }

    public entry fun add_to_sanction_list(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::add_to_sanction_list(&mut state.rule_engine, account, ctx);
    }

    public entry fun remove_from_sanction_list(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::remove_from_sanction_list(&mut state.rule_engine, account, ctx);
    }

    public entry fun set_max_balance(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        max_balance: u64,
        ctx: &mut tx_context::TxContext
    ) {
        rule_engine_v2::set_max_balance(&mut state.rule_engine, max_balance, ctx);
    }

    // ========== RULE ENGINE REMOVAL/RESTORATION ==========
    public entry fun remove_rule_engine(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(state.rule_engine_active, ERuleEngineNotActive);
        state.rule_engine_active = false;

        event::emit(RuleEngineRemoved {
            admin: tx_context::sender(ctx),
        });
    }

    public entry fun restore_rule_engine(
        _admin_cap: &AdminCap,
        state: &mut DebtCMTATState,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(!state.rule_engine_active, ERuleEngineAlreadyActive);
        state.rule_engine_active = true;

        event::emit(RuleEngineRestored {
            admin: tx_context::sender(ctx),
        });
    }

    // ========== TRANSFER FUNCTIONS WITH VALIDATION ==========
    public entry fun transfer(
        registry: &CMTATRegistry,
        state: &mut DebtCMTATState,
        compliance_state: &ComplianceState,
        deny_list: &deny_list::DenyList,
        clock: &Clock,
        coins: Coin<DEBT_CMTAT>,
        to: address,
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);

        // Check deactivation
        assert!(!registry.deactivated, EModuleDeactivated);

        // Check debt default status
        assert!(!is_default_flagged(compliance_state), EDebtInDefault);

        // Check native DenyList
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);

        // RuleEngine validation (if active)
        if (state.rule_engine_active) {
            let is_from_vip = rule_engine_v2::is_vip(&state.rule_engine, from);
            let is_to_vip = rule_engine_v2::is_vip(&state.rule_engine, to);
            
            rule_engine_v2::require_valid_transfer(
                &state.rule_engine,
                from,
                to,
                coin::value(&coins),
                clock,
                is_from_vip && is_to_vip,
                0 // Max balance check deferred
            );
        };

        // Transfer the coins
        transfer::public_transfer(coins, to);
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(DEBT_CMTAT {}, ctx);
    }
}
