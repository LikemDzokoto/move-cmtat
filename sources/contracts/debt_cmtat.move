/// Debt CMTAT - Native Coin<T> for Debt Securities
/// Specialized for corporate bonds and debt instruments
/// Implements debt-specific controls 
#[allow(unused_const)]
module move_cmtat::debt_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list;

    use iota::clock::{Self, Clock};
    use iota::event;

    use move_cmtat::debt;
    use move_cmtat::snapshot_engine;
    use move_cmtat::rule_engine_v2;
    use move_cmtat::interest_engine;


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

    // ========== STATE WITH EMBEDDED DEBT + INTEREST ENGINE ==========
    public struct DebtCMTATState has key {
        id: object::UID,
        snapshot_engine: snapshot_engine::SnapshotEngine,
        rule_engine: rule_engine_v2::RuleEngine,
        rule_engine_active: bool,
        // EMBEDDED: Full debt state (identifier, instrument, terms, credit events)
        debt_state: debt::DebtState,
        // EMBEDDED: Interest engine for coupon management
        interest_engine: interest_engine::InterestEngineState,
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

    public struct DebtIdentifierUpdated has copy, drop {
        debt_manager: address,
    }

    public struct DebtInstrumentUpdated has copy, drop {
        debt_manager: address,
    }

    public struct BondTermsUpdated has copy, drop {
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
    const EMaturityReached: u64 = 7;
    const ENotMaturedOrDefault: u64 = 8;
    const EInvalidDenomination: u64 = 9;


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

        // state with snapshot engine, rule engine, debt state, and interest engine
        let state = DebtCMTATState {    
            id: object::new(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
            rule_engine: rule_engine_v2::init_rule_engine_v2(ctx),
            rule_engine_active: true,
            debt_state: debt::init_debt_state(ctx),
            interest_engine: interest_engine::init_interest_engine(ctx),
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
    public fun debt_info(state: &DebtCMTATState): String {
        debt::get_debt(&state.debt_state)
    }

    public fun credit_events(state: &DebtCMTATState): debt::CreditEvents {
        debt::get_credit_events(&state.debt_state)
    }

    public fun debt_engine(state: &DebtCMTATState): address {
        debt::get_debt_engine(&state.debt_state)
    }

    public fun is_default_flagged(state: &DebtCMTATState): bool {
        debt::is_default_flagged(&state.debt_state)
    }

    public fun is_matured(state: &DebtCMTATState, current_time: u64): bool {
        debt::is_matured_at_time(current_time, &state.debt_state)
    }

    public fun is_redeemed(state: &DebtCMTATState): bool {
        debt::is_fully_redeemed(&state.debt_state)
    }

    // ========== DEBT IDENTIFIER VIEWS ==========
    public fun get_issuer_name(state: &DebtCMTATState): String {
        debt::get_issuer_name(&state.debt_state)
    }

    public fun get_issuer_description(state: &DebtCMTATState): String {
        debt::get_issuer_description(&state.debt_state)
    }

    public fun get_isin(state: &DebtCMTATState): String {
        debt::get_isin(&state.debt_state)
    }

    // ========== DEBT INSTRUMENT VIEWS ==========
    public fun get_interest_rate(state: &DebtCMTATState): u64 {
        debt::get_interest_rate(&state.debt_state)
    }

    public fun get_par_value(state: &DebtCMTATState): u64 {
        debt::get_par_value(&state.debt_state)
    }

    public fun get_minimum_denomination(state: &DebtCMTATState): u64 {
        debt::get_minimum_denomination(&state.debt_state)
    }

    public fun get_maturity_date(state: &DebtCMTATState): u64 {
        debt::get_maturity_date(&state.debt_state)
    }

    public fun get_issuance_date(state: &DebtCMTATState): u64 {
        debt::get_issuance_date(&state.debt_state)
    }

    public fun get_coupon_frequency(state: &DebtCMTATState): String {
        debt::get_coupon_frequency(&state.debt_state)
    }

    public fun get_rating(state: &DebtCMTATState): String {
        debt::get_rating(&state.debt_state)
    }

    // ========== INTEREST ENGINE VIEWS ==========
    public fun get_total_interest_accrued(state: &DebtCMTATState, current_time: u64): u64 {
        interest_engine::get_total_interest_accrued(&state.interest_engine, current_time)
    }

    public fun get_total_interest_paid(state: &DebtCMTATState): u64 {
        interest_engine::get_total_interest_paid(&state.interest_engine)
    }

    public fun get_coupons_remaining(state: &DebtCMTATState): u64 {
        interest_engine::get_coupons_remaining(&state.interest_engine)
    }

    public fun is_coupon_schedule_generated(state: &DebtCMTATState): bool {
        interest_engine::is_schedule_generated(&state.interest_engine)
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
    
    // ---- Debt Identifier ----
    public entry fun set_debt_identifier(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        issuer_name: String,
        issuer_description: String,
        guarantor: String,
        debt_holder_representative: String,
        isin: String,
        ctx: &tx_context::TxContext
    ) {
        let identifier = debt::create_debt_identifier(
            issuer_name,
            issuer_description,
            guarantor,
            debt_holder_representative,
            isin
        );
        debt::set_debt_identifier(&mut state.debt_state, identifier);

        event::emit(DebtIdentifierUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    // ---- Debt Instrument ----
    public entry fun set_debt_instrument(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        interest_rate: u64,
        par_value: u64,
        minimum_denomination: u64,
        issuance_date: u64,
        maturity_date: u64,
        coupon_frequency: String,
        interest_schedule_format: String,
        interest_payment_date: String,
        day_count_convention: u8,
        business_day_convention: u8,
        currency: String,
        currency_contract: address,
        ctx: &tx_context::TxContext
    ) {
        let instrument = debt::create_debt_instrument(
            interest_rate,
            par_value,
            minimum_denomination,
            issuance_date,
            maturity_date,
            coupon_frequency,
            interest_schedule_format,
            interest_payment_date,
            debt::u8_to_day_count(day_count_convention),
            debt::u8_to_business_day(business_day_convention),
            currency,
            currency_contract
        );
        debt::set_debt_instrument(&mut state.debt_state, instrument);

        event::emit(DebtInstrumentUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    // ---- Bond Terms ----
    public entry fun set_bond_terms(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        call_schedule: String,
        put_schedule: String,
        sinking_fund_schedule: String,
        convertible_terms: String,
        collateral_description: String,
        ctx: &tx_context::TxContext
    ) {
        let terms = debt::create_bond_terms(
            call_schedule,
            put_schedule,
            sinking_fund_schedule,
            convertible_terms,
            collateral_description
        );
        debt::set_bond_terms(&mut state.debt_state, terms);

        event::emit(BondTermsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    // ---- Credit Events ----
    public entry fun set_rating(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        rating: String,
        ctx: &tx_context::TxContext
    ) {
        debt::set_rating(&mut state.debt_state, rating);

        event::emit(CreditEventsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun flag_default(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        ctx: &tx_context::TxContext
    ) {
        debt::flag_default(&mut state.debt_state);

        event::emit(DebtFlagged {
            debt_cap_holder: tx_context::sender(ctx),
        });
    }

    public entry fun flag_redeemed(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        ctx: &tx_context::TxContext
    ) {
        debt::flag_redeemed(&mut state.debt_state);

        event::emit(CreditEventsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun set_next_coupon_date(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        next_coupon_date: u64,
        ctx: &tx_context::TxContext
    ) {
        debt::set_next_coupon_date(&mut state.debt_state, next_coupon_date);

        event::emit(CreditEventsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    // ---- Legacy setters (backward compatibility) ----
    public entry fun set_debt(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        debt_info: String,
        ctx: &tx_context::TxContext
    ) {
        debt::set_debt(&mut state.debt_state, debt_info);

        event::emit(DebtUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun set_credit_events(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
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
        debt::set_credit_events(&mut state.debt_state, credit_events);

        event::emit(CreditEventsUpdated {
            debt_manager: tx_context::sender(ctx),
        });
    }

    public entry fun set_debt_engine(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        engine: address,
        ctx: &tx_context::TxContext
    ) {
        debt::set_debt_engine(&mut state.debt_state, engine);

        event::emit(DebtEngineUpdated {
            debt_manager: tx_context::sender(ctx),
            engine,
        });
    }

    // ========== MINTING FUNCTIONS  ==========
    public fun mint(
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        state: &DebtCMTATState,
        deny_list: &deny_list::DenyList,
        to: address,
        amount: u64,
        ctx: &mut tx_context::TxContext
    ): Coin<DEBT_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);
        debt::require_not_in_default(&state.debt_state);

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

        let coins = mint(treasury_cap, registry, state, deny_list, to, amount, ctx);
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

    // ========== TRANSFER VALIDATION (Internal) ==========
    fun validate_transfer(
        state: &DebtCMTATState,
        amount: u64,
        current_time: u64,
    ) {
        // Block if matured - transfers only allowed before maturity
        assert!(!debt::is_matured_at_time(current_time, &state.debt_state), EMaturityReached);
        
        // Block if in default
        debt::require_not_in_default(&state.debt_state);
        
        // Validate minimum denomination
        debt::require_valid_minimum_denomination(&state.debt_state, amount);
    }

    // ========== TRANSFER FUNCTIONS WITH VALIDATION ==========
    public entry fun transfer(
        registry: &CMTATRegistry,
        state: &mut DebtCMTATState,
        deny_list: &deny_list::DenyList,
        clock: &Clock,
        coins: Coin<DEBT_CMTAT>,
        to: address,
        ctx: &tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = coin::value(&coins);
        let current_time = clock::timestamp_ms(clock);

        // Check deactivation
        assert!(!registry.deactivated, EModuleDeactivated);

        // Check debt default + maturity + denomination
        validate_transfer(state, amount, current_time);

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
                amount,
                clock,
                is_from_vip && is_to_vip,
                0 // Max balance check deferred
            );
        };

        // Transfer the coins
        transfer::public_transfer(coins, to);
    }

    // ========== REDEMPTION FUNCTION ==========
    public entry fun redeem(
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        registry: &CMTATRegistry,
        state: &mut DebtCMTATState,
        deny_list: &deny_list::DenyList,
        clock: &Clock,
        coins: Coin<DEBT_CMTAT>,
        ctx: &mut tx_context::TxContext
    ) {
        let amount = coin::value(&coins);
        let current_time = clock::timestamp_ms(clock);

        // Check deactivation
        assert!(!registry.deactivated, EModuleDeactivated);

        // Check native DenyList
        assert!(!is_paused(deny_list, ctx), EModulePaused);

        // Only allowed when matured OR in default
        let is_matured = debt::is_matured_at_time(current_time, &state.debt_state);
        let is_default = debt::is_default(&state.debt_state);
        assert!(is_matured || is_default, ENotMaturedOrDefault);

        // Validate minimum denomination
        debt::require_valid_minimum_denomination(&state.debt_state, amount);

        // Burn the tokens
        coin::burn(treasury_cap, coins);

        // Update principal distributed
        debt::record_principal_distribution(&mut state.debt_state, amount);

        // Emit redemption event
        event::emit(TokenBurned {
            burner: tx_context::sender(ctx),
            from: tx_context::sender(ctx),
            amount,
        });
    }

    // ========== INTEREST ENGINE FUNCTIONS ==========
    
    // ---- Coupon Schedule ----
    public entry fun generate_coupon_schedule(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        treasury_cap: &TreasuryCap<DEBT_CMTAT>,
        _clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Read from debt instrument to get params
        let issuance_date = debt::get_issuance_date(&state.debt_state);
        let maturity_date = debt::get_maturity_date(&state.debt_state);
        let frequency = debt::get_coupon_frequency(&state.debt_state);
        let rate = debt::get_interest_rate(&state.debt_state);
        let par_value = debt::get_par_value(&state.debt_state);
        let total_supply = coin::total_supply(treasury_cap);
        let day_count_convention = debt::day_count_to_u8(&debt::get_day_count_convention(&state.debt_state));

        // Generate schedule using interest engine
        interest_engine::generate_coupon_schedule(
            &mut state.interest_engine,
            issuance_date,
            maturity_date,
            frequency,
            rate,
            par_value,
            total_supply,
            day_count_convention,
            ctx
        );
    }

    // ---- Coupon Payment Recording ----
    public entry fun record_coupon_payment(
        _debt_cap: &DebtCap,
        state: &mut DebtCMTATState,
        coupon_number: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let payment_time = clock::timestamp_ms(clock);
        interest_engine::record_coupon_payment(
            &mut state.interest_engine,
            coupon_number,
            payment_time,
            ctx
        );
    }

    // ---- Coupon Claims ----
    public fun get_claimable_amount(
        state: &DebtCMTATState,
        coupon_number: u64,
        holder_balance: u64
    ): u64 {
        interest_engine::calculate_account_interest(
            &state.interest_engine,
            coupon_number,
            holder_balance
        )
    }

    public fun get_next_coupon(state: &DebtCMTATState): Option<interest_engine::CouponPayment> {
        interest_engine::get_next_coupon(&state.interest_engine)
    }

    public fun get_upcoming_coupons(state: &DebtCMTATState, current_time: u64): vector<interest_engine::CouponPayment> {
        interest_engine::get_upcoming_coupons(&state.interest_engine, current_time)
    }

    public fun get_unpaid_coupons(state: &DebtCMTATState): vector<interest_engine::CouponPayment> {
        interest_engine::get_unpaid_coupons(&state.interest_engine)
    }

    // ========== COUPON CLAIM FUNCTIONS ==========

    /// Check if a coupon has been claimed by a holder
    public fun is_coupon_claimed(
        state: &DebtCMTATState,
        coupon_number: u64,
        holder: address
    ): bool {
        interest_engine::is_claimed(&state.interest_engine, coupon_number, holder)
    }

    /// Claim coupon interest for a specific holder
    /// This calculates the holder's entitlement based on their balance at record date
    /// and records the claim to prevent double-claiming
    public fun claim_coupon(
        state: &mut DebtCMTATState,
        treasury_cap: &mut TreasuryCap<DEBT_CMTAT>,
        coupon_number: u64,
        holder_balance: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ): Coin<DEBT_CMTAT> {
        let current_time = clock::timestamp_ms(clock);
        let holder = tx_context::sender(ctx);
        
        // Call interest engine to process claim
        let amount = interest_engine::claim_coupon(
            &mut state.interest_engine,
            coupon_number,
            holder,
            holder_balance,
            current_time
        );
        
        // Mint the claimed interest to the holder
        if (amount > 0) {
            let coins = coin::mint(treasury_cap, amount, ctx);
            coins
        } else {
            coin::zero(ctx)
        }
    }

    /// Get total number of claims recorded
    public fun get_claim_count(state: &DebtCMTATState): u64 {
        interest_engine::get_claim_count(&state.interest_engine)
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(DEBT_CMTAT {}, ctx);
    }
}
