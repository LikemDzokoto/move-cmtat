/// Debt Engine - Multi-Token External Debt Management
/// Centralized contract for managing debt data across multiple tokens
/// Reduces per-token contract size by externalizing debt storage
module move_cmtat::debt_engine {
    use std::string::{Self, String};
    use iota::table::{Self, Table};
    use iota::event;
    use iota::clock;
    use iota::tx_context::{Self, TxContext};
    use std::vector;
    use std::option::{Self, Option};
    use move_cmtat::debt::{Self, DebtState, DebtIdentifier, DebtInstrument, CreditEvents, BondTerms};

    // ========== ERRORS ==========
    
    const ETokenNotRegistered: u64 = 900;
    const ETokenAlreadyRegistered: u64 = 901;
    const EInvalidTokenAddress: u64 = 902;
    const EUnauthorized: u64 = 903;
    const EInvalidDebtData: u64 = 904;

    // ========== STRUCTS ==========
    
    /// Aggregated debt data for a token
    public struct TokenDebtData has copy, drop, store {
        identifier: DebtIdentifier,
        instrument: DebtInstrument,
        terms: BondTerms,
        credit_events: CreditEvents,
        registration_time: u64,
        last_updated: u64,
    }

    /// Debt engine state
    public struct DebtEngineState has key {
        id: UID,
        token_debt_data: Table<address, TokenDebtData>,  // token_address -> TokenDebtData
        supported_tokens: vector<address>,
        admin_address: address,
    }

    /// Admin capability for debt engine
    public struct DebtEngineAdminCap has key, store {
        id: UID,
        engine_id: address,
    }

    // ========== EVENTS ==========
    
    public struct TokenRegistered has copy, drop {
        token_address: address,
        registered_by: address,
        registration_time: u64,
        issuer_name: String,
    }

    public struct TokenDebtUpdated has copy, drop {
        token_address: address,
        updated_by: address,
        update_time: u64,
        update_type: String,  // "IDENTIFIER", "INSTRUMENT", "TERMS", "CREDIT_EVENTS"
    }

    public struct TokenUnregistered has copy, drop {
        token_address: address,
        unregistered_by: address,
        unregistration_time: u64,
    }

    public struct CreditEventTriggered has copy, drop {
        token_address: address,
        event_type: String,  // "DEFAULT", "REDEMPTION", "MATURITY", "RATING_CHANGE"
        triggered_by: address,
        timestamp: u64,
    }

    // ========== INITIALIZATION ==========
    
    /// Initialize debt engine
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        
        let state = DebtEngineState {
            id: object::new(ctx),
            token_debt_data: table::new(ctx),
            supported_tokens: vector::empty(),
            admin_address: sender,
        };

        let admin_cap = DebtEngineAdminCap {
            id: object::new(ctx),
            engine_id: object::id_address(&state),
        };

        transfer::share_object(state);
        transfer::transfer(admin_cap, sender);
    }

    // ========== TOKEN REGISTRATION ==========
    
    /// Register a new token with the debt engine
    public fun register_token(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        identifier: DebtIdentifier,
        instrument: DebtInstrument,
        terms: BondTerms,
        current_time: u64,
        ctx: &TxContext
    ) {
        // Validate not already registered
        assert!(!is_token_registered(state, token_address), ETokenAlreadyRegistered);
        assert!(token_address != @0x0, EInvalidTokenAddress);

        let debt_data = TokenDebtData {
            identifier,
            instrument,
            terms,
            credit_events: debt::init_credit_events(),
            registration_time: current_time,
            last_updated: current_time,
        };

        // Store debt data
        table::add(&mut state.token_debt_data, token_address, debt_data);
        vector::push_back(&mut state.supported_tokens, token_address);

        // Emit event
        event::emit(TokenRegistered {
            token_address,
            registered_by: tx_context::sender(ctx),
            registration_time: current_time,
            issuer_name: debt::identifier_get_issuer_name(&identifier),
        });
    }

    /// Register token with full data including initial credit events
    public fun register_token_full(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        identifier: DebtIdentifier,
        instrument: DebtInstrument,
        terms: BondTerms,
        credit_events: CreditEvents,
        current_time: u64,
        ctx: &TxContext
    ) {
        assert!(!is_token_registered(state, token_address), ETokenAlreadyRegistered);
        assert!(token_address != @0x0, EInvalidTokenAddress);

        let debt_data = TokenDebtData {
            identifier,
            instrument,
            terms,
            credit_events,
            registration_time: current_time,
            last_updated: current_time,
        };

        table::add(&mut state.token_debt_data, token_address, debt_data);
        vector::push_back(&mut state.supported_tokens, token_address);

        event::emit(TokenRegistered {
            token_address,
            registered_by: tx_context::sender(ctx),
            registration_time: current_time,
            issuer_name: debt::identifier_get_issuer_name(&identifier),
        });
    }

    /// Unregister token from debt engine
    public fun unregister_token(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        current_time: u64,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        table::remove(&mut state.token_debt_data, token_address);
        
        // Remove from supported tokens list
        let (found, idx) = vector::index_of(&state.supported_tokens, &token_address);
        if (found) {
            vector::remove(&mut state.supported_tokens, idx);
        };

        event::emit(TokenUnregistered {
            token_address,
            unregistered_by: tx_context::sender(ctx),
            unregistration_time: current_time,
        });
    }

    // ========== DATA UPDATES ==========
    
    /// Update token debt identifier
    public fun update_token_identifier(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        identifier: DebtIdentifier,
        current_time: u64,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        debt_data.identifier = identifier;
        debt_data.last_updated = current_time;

        event::emit(TokenDebtUpdated {
            token_address,
            updated_by: tx_context::sender(ctx),
            update_time: debt_data.last_updated,
            update_type: std::string::utf8(b"IDENTIFIER"),
        });
    }

    /// Update token debt instrument
    public fun update_token_instrument(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        instrument: DebtInstrument,
        current_time: u64,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        debt_data.instrument = instrument;
        debt_data.last_updated = current_time;

        event::emit(TokenDebtUpdated {
            token_address,
            updated_by: tx_context::sender(ctx),
            update_time: debt_data.last_updated,
            update_type: std::string::utf8(b"INSTRUMENT"),
        });
    }

    /// Update token bond terms
    public fun update_token_terms(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        terms: BondTerms,
        current_time: u64,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        debt_data.terms = terms;
        debt_data.last_updated = current_time;

        event::emit(TokenDebtUpdated {
            token_address,
            updated_by: tx_context::sender(ctx),
            update_time: debt_data.last_updated,
            update_type: string::utf8(b"TERMS"),
        });
    }

    /// Update token credit events
    public fun update_token_credit_events(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        credit_events: CreditEvents,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();

        event::emit(TokenDebtUpdated {
            token_address,
            updated_by: tx_context::sender(ctx),
            update_time: debt_data.last_updated,
            update_type: string::utf8(b"CREDIT_EVENTS"),
        });
    }

    // ========== CREDIT EVENT OPERATIONS ==========
    
    /// Flag token as in default
    public fun flag_token_default(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_flag_default(&mut credit_events);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();

        event::emit(CreditEventTriggered {
            token_address,
            event_type: string::utf8(b"DEFAULT"),
            triggered_by: tx_context::sender(ctx),
            timestamp: debt_data.last_updated,
        });
    }

    /// Clear token default flag
    public fun clear_token_default(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_clear_default(&mut credit_events);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();
    }

    /// Flag token as redeemed
    public fun flag_token_redeemed(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_flag_redeemed(&mut credit_events);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();

        event::emit(CreditEventTriggered {
            token_address,
            event_type: string::utf8(b"REDEMPTION"),
            triggered_by: tx_context::sender(ctx),
            timestamp: debt_data.last_updated,
        });
    }

    /// Flag token as matured
    public fun flag_token_matured(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_flag_matured(&mut credit_events);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();

        event::emit(CreditEventTriggered {
            token_address,
            event_type: string::utf8(b"MATURITY"),
            triggered_by: tx_context::sender(ctx),
            timestamp: debt_data.last_updated,
        });
    }

    /// Update token credit rating
    public fun update_token_rating(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        rating: String,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_set_rating(&mut credit_events, rating);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();

        event::emit(CreditEventTriggered {
            token_address,
            event_type: string::utf8(b"RATING_CHANGE"),
            triggered_by: tx_context::sender(ctx),
            timestamp: debt_data.last_updated,
        });
    }

    /// Record principal distribution
    public fun record_token_principal_distribution(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_address: address,
        amount: u64,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);

        let debt_data = table::borrow_mut(&mut state.token_debt_data, token_address);
        let mut credit_events = debt_data.credit_events;
        debt::credit_events_record_principal(&mut credit_events, amount);
        debt_data.credit_events = credit_events;
        debt_data.last_updated = clock.timestamp_ms();
    }

    // ========== QUERIES ==========
    
    /// Get full debt data for a token
    public fun get_token_debt_data(
        state: &DebtEngineState,
        token_address: address
    ): TokenDebtData {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        *table::borrow(&state.token_debt_data, token_address)
    }

    /// Try get token debt data
    public fun try_get_token_debt_data(
        state: &DebtEngineState,
        token_address: address
    ): Option<TokenDebtData> {
        if (is_token_registered(state, token_address)) {
            option::some(*table::borrow(&state.token_debt_data, token_address))
        } else {
            option::none()
        }
    }

    /// Check if token is registered
    public fun is_token_registered(state: &DebtEngineState, token_address: address): bool {
        table::contains(&state.token_debt_data, token_address)
    }

    /// Get token identifier
    public fun get_token_identifier(
        state: &DebtEngineState,
        token_address: address
    ): DebtIdentifier {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).identifier
    }

    /// Get token instrument
    public fun get_token_instrument(
        state: &DebtEngineState,
        token_address: address
    ): DebtInstrument {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).instrument
    }

    /// Get token credit events
    public fun get_token_credit_events(
        state: &DebtEngineState,
        token_address: address
    ): CreditEvents {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).credit_events
    }

    /// Get token bond terms
    public fun get_token_terms(
        state: &DebtEngineState,
        token_address: address
    ): BondTerms {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).terms
    }

    /// Get all registered tokens
    public fun get_registered_tokens(state: &DebtEngineState): vector<address> {
        state.supported_tokens
    }

    /// Get registered token count
    public fun get_token_count(state: &DebtEngineState): u64 {
        vector::length(&state.supported_tokens)
    }

    /// Get registration time for token
    public fun get_token_registration_time(
        state: &DebtEngineState,
        token_address: address
    ): u64 {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).registration_time
    }

    /// Get last update time for token
    public fun get_token_last_updated(
        state: &DebtEngineState,
        token_address: address
    ): u64 {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
        table::borrow(&state.token_debt_data, token_address).last_updated
    }

    /// Check if token is in default
    public fun is_token_in_default(state: &DebtEngineState, token_address: address): bool {
        if (!is_token_registered(state, token_address)) {
            return false
        };
        let credit_events = get_token_credit_events(state, token_address);
        debt::credit_events_is_default(&credit_events)
    }

    /// Check if token is redeemed
    public fun is_token_redeemed(state: &DebtEngineState, token_address: address): bool {
        if (!is_token_registered(state, token_address)) {
            return false
        };
        let credit_events = get_token_credit_events(state, token_address);
        debt::credit_events_is_redeemed(&credit_events)
    }

    /// Check if token is matured
    public fun is_token_matured(state: &DebtEngineState, token_address: address): bool {
        if (!is_token_registered(state, token_address)) {
            return false
        };
        let credit_events = get_token_credit_events(state, token_address);
        debt::credit_events_is_matured(&credit_events)
    }

    /// Get token credit rating
    public fun get_token_rating(
        state: &DebtEngineState,
        token_address: address
    ): String {
        if (!is_token_registered(state, token_address)) {
            return string::utf8(b"")
        };
        let credit_events = get_token_credit_events(state, token_address);
        debt::credit_events_get_rating(&credit_events)
    }

    /// Get token interest rate
    public fun get_token_interest_rate(
        state: &DebtEngineState,
        token_address: address
    ): u64 {
        if (!is_token_registered(state, token_address)) {
            return 0
        };
        debt::instrument_get_interest_rate(&get_token_instrument(state, token_address))
    }

    /// Get token maturity date
    public fun get_token_maturity_date(
        state: &DebtEngineState,
        token_address: address
    ): u64 {
        if (!is_token_registered(state, token_address)) {
            return 0
        };
        debt::instrument_get_maturity_date(&get_token_instrument(state, token_address))
    }

    // ========== VALIDATION ==========
    
    /// Require token is registered
    public fun require_token_registered(state: &DebtEngineState, token_address: address) {
        assert!(is_token_registered(state, token_address), ETokenNotRegistered);
    }

    /// Require token is not in default
    public fun require_token_not_in_default(state: &DebtEngineState, token_address: address) {
        assert!(!is_token_in_default(state, token_address), EInvalidDebtData);
    }

    /// Require token is not redeemed
    public fun require_token_not_redeemed(state: &DebtEngineState, token_address: address) {
        assert!(!is_token_redeemed(state, token_address), EInvalidDebtData);
    }

    // ========== ADMIN FUNCTIONS ==========
    
    /// Transfer admin capability
    public entry fun transfer_admin_cap(
        admin_cap: DebtEngineAdminCap,
        new_admin: address
    ) {
        transfer::transfer(admin_cap, new_admin);
    }

    /// Update admin address
    public entry fun update_admin_address(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        new_admin: address
    ) {
        state.admin_address = new_admin;
    }

    /// Get admin address
    public fun get_admin_address(state: &DebtEngineState): address {
        state.admin_address
    }

    // ========== HELPER FUNCTIONS ==========

    /// Batch update multiple tokens
    public fun batch_update_credit_events(
        _admin_cap: &DebtEngineAdminCap,
        state: &mut DebtEngineState,
        token_addresses: vector<address>,
        credit_events: CreditEvents,
        clock: &clock::Clock,
        ctx: &TxContext
    ) {
        let len = vector::length(&token_addresses);
        let mut i = 0;
        
        while (i < len) {
            let token_address = *vector::borrow(&token_addresses, i);
            if (is_token_registered(state, token_address)) {
                update_token_credit_events(_admin_cap, state, token_address, credit_events, clock, ctx);
            };
            i = i + 1;
        }
    }

    /// Get engine statistics
    public fun get_engine_stats(state: &DebtEngineState): (u64, u64, u64) {
        let total = get_token_count(state);
        let mut defaulted = 0;
        let mut redeemed = 0;

        let mut i = 0;
        while (i < total) {
            let token_address = *vector::borrow(&state.supported_tokens, i);
            if (is_token_in_default(state, token_address)) {
                defaulted = defaulted + 1;
            };
            if (is_token_redeemed(state, token_address)) {
                redeemed = redeemed + 1;
            };
            i = i + 1;
        };

        (total, defaulted, redeemed)
    }
}
