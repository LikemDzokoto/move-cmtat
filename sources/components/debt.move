/// Debt Component - Full Bond Instrument Management
/// Comprehensive debt securities management for corporate bonds
/// Implements CMTAT DebtModule specification with structured data types
#[allow(unused_const, duplicate_alias)]
module move_cmtat::debt {
    use std::string::{Self, String};
    use iota::object;

    // ========== CONSTANTS ==========
    
    /// Fixed-point multiplier for interest rates (6 decimals)
    /// Rate of 5.25% = 5,250,000
    const INTEREST_RATE_MULTIPLIER: u64 = 1_000_000;
    
    /// Day count denominators
    const DAYS_360: u64 = 360;
    const DAYS_365: u64 = 365;

    // ========== ERRORS ==========
    
    const EDebtInDefault: u64 = 400;
    const EAlreadyRedeemed: u64 = 401;
    const EInvalidDenomination: u64 = 402;
    const EInvalidMaturityDate: u64 = 403;
    const EInvalidInterestRate: u64 = 404;

    // ========== ENUMS ==========
    
    /// Day count conventions for interest calculations
    public enum DayCountConvention has copy, drop, store {
        Thirty360,        // 30/360 convention
        Actual360,        // Actual/360 convention
        Actual365,        // Actual/365 convention
        ActualActual,     // Actual/Actual convention
    }

    /// Business day conventions for date adjustments
    public enum BusinessDayConvention has copy, drop, store {
        Following,           // Move to next business day
        ModifiedFollowing,   // Move to next, but not next month
        Preceding,          // Move to previous business day
        Unadjusted,         // No adjustment
    }

    // ========== DAY COUNT CONVENTION CONSTANTS ==========
    /// For external modules that can't match on enums
    const DAY_COUNT_THIRTY360: u8 = 0;
    const DAY_COUNT_ACTUAL360: u8 = 1;
    const DAY_COUNT_ACTUAL365: u8 = 2;
    const DAY_COUNT_ACTUALACTUAL: u8 = 3;

    // ========== BUSINESS DAY CONVENTION CONSTANTS ==========
    const BDC_FOLLOWING: u8 = 0;
    const BDC_MODIFIED_FOLLOWING: u8 = 1;
    const BDC_PRECEDING: u8 = 2;
    const BDC_UNADJUSTED: u8 = 3;

    // ========== ENUM CONVERSION FUNCTIONS ==========

    /// Convert DayCountConvention to u8 constant
    public fun day_count_to_u8(convention: &DayCountConvention): u8 {
        match (convention) {
            DayCountConvention::Thirty360 => DAY_COUNT_THIRTY360,
            DayCountConvention::Actual360 => DAY_COUNT_ACTUAL360,
            DayCountConvention::Actual365 => DAY_COUNT_ACTUAL365,
            DayCountConvention::ActualActual => DAY_COUNT_ACTUALACTUAL,
        }
    }

    /// Convert u8 constant to DayCountConvention
    public fun u8_to_day_count(value: u8): DayCountConvention {
        if (value == DAY_COUNT_THIRTY360) {
            DayCountConvention::Thirty360
        } else if (value == DAY_COUNT_ACTUAL360) {
            DayCountConvention::Actual360
        } else if (value == DAY_COUNT_ACTUAL365) {
            DayCountConvention::Actual365
        } else {
            DayCountConvention::ActualActual
        }
    }

    /// Convert BusinessDayConvention to u8 constant
    public fun business_day_to_u8(convention: &BusinessDayConvention): u8 {
        match (convention) {
            BusinessDayConvention::Following => BDC_FOLLOWING,
            BusinessDayConvention::ModifiedFollowing => BDC_MODIFIED_FOLLOWING,
            BusinessDayConvention::Preceding => BDC_PRECEDING,
            BusinessDayConvention::Unadjusted => BDC_UNADJUSTED,
        }
    }

    /// Convert u8 constant to BusinessDayConvention
    public fun u8_to_business_day(value: u8): BusinessDayConvention {
        if (value == BDC_FOLLOWING) {
            BusinessDayConvention::Following
        } else if (value == BDC_MODIFIED_FOLLOWING) {
            BusinessDayConvention::ModifiedFollowing
        } else if (value == BDC_PRECEDING) {
            BusinessDayConvention::Preceding
        } else {
            BusinessDayConvention::Unadjusted
        }
    }

    // ========== CONSTANT GETTERS ==========
    /// Getters for day count constants (for external modules)
    
    public fun day_count_thirty360(): u8 { DAY_COUNT_THIRTY360 }
    public fun day_count_actual360(): u8 { DAY_COUNT_ACTUAL360 }
    public fun day_count_actual365(): u8 { DAY_COUNT_ACTUAL365 }
    public fun day_count_actualactual(): u8 { DAY_COUNT_ACTUALACTUAL }

    /// Getters for business day convention constants
    
    public fun bdc_following(): u8 { BDC_FOLLOWING }
    public fun bdc_modified_following(): u8 { BDC_MODIFIED_FOLLOWING }
    public fun bdc_preceding(): u8 { BDC_PRECEDING }
    public fun bdc_unadjusted(): u8 { BDC_UNADJUSTED }

    // ========== DATA STRUCTURES ==========
    
    /// DebtIdentifier - Entity identification for regulatory compliance
    /// Contains LEI, ISIN, and entity information
    public struct DebtIdentifier has copy, drop, store {
        issuer_name: String,                    // LEI or entity name
        issuer_description: String,             // Detailed description
        guarantor: String,                      // LEI/UID of guarantor (if applicable)
        debt_holder_representative: String,     // Debtholder representative identifier
        isin: String,                           // ISIN or other security identifier
    }

    /// DebtInstrument - Complete bond instrument specification
    /// All terms and conditions of the debt security
    public struct DebtInstrument has copy, drop, store {
        // Core bond terms
        interest_rate: u64,                     // Fixed-point: rate * INTEREST_RATE_MULTIPLIER
        par_value: u64,                         // Face value per bond
        minimum_denomination: u64,              // Minimum tradable amount
        
        // Dates (Unix timestamps in seconds)
        issuance_date: u64,
        maturity_date: u64,
        
        // Payment terms
        coupon_frequency: String,               // "ANNUAL", "SEMI_ANNUAL", "QUARTERLY", "MONTHLY"
        interest_schedule_format: String,       // Format description
        interest_payment_date: String,          // Description or specific date
        
        // Conventions
        day_count_convention: DayCountConvention,
        business_day_convention: BusinessDayConvention,
        
        // Currency
        currency: String,                       // ISO 4217 code (e.g., "USD", "EUR")
        currency_contract: address,             // Address of currency token contract
    }

    /// CreditEvents - Structured credit event tracking
    /// Tracks default, redemption, maturity, and rating status
    public struct CreditEvents has copy, drop, store {
        flag_default: bool,                     // Default event occurred
        flag_redeemed: bool,                    // Bond fully redeemed
        flag_matured: bool,                     // Bond reached maturity date
        rating: String,                         // Current credit rating (e.g., "AAA", "BB+")
        principal_distributed: u64,             // Total principal distributed to holders
        next_coupon_date: u64,                  // Timestamp of next coupon payment
    }

    /// BondTerms - Additional bond-specific terms
    /// Optional provisions and schedules
    public struct BondTerms has copy, drop, store {
        call_schedule: String,                  // Call provisions (if any)
        put_schedule: String,                   // Put provisions (if any)
        sinking_fund_schedule: String,          // Sinking fund provisions
        convertible_terms: String,              // Conversion terms (if convertible)
        collateral_description: String,         // Collateral backing the bond
    }

    /// DebtState - Main state structure for debt tracking
    /// Enhanced version with structured data types
    public struct DebtState has key, store {
        id: object::UID,
        
        // Structured debt information
        identifier: DebtIdentifier,
        instrument: DebtInstrument,
        terms: BondTerms,
        credit_events: CreditEvents,
        
        // DebtEngine integration
        debt_engine: address,                   // External engine address (0x0 if disabled)
        use_external_engine: bool,              // Toggle for external vs internal storage
        
        // Legacy fields (backward compatibility)
        debt_info_legacy: String,
        credit_events_legacy: String,
    }

    // ========== INITIALIZATION ==========
    
    /// Initialize empty debt state
    public fun init_debt_state(ctx: &mut TxContext): DebtState {
        DebtState {
            id: object::new(ctx),
            identifier: init_debt_identifier(),
            instrument: init_debt_instrument(),
            terms: init_bond_terms(),
            credit_events: init_credit_events(),
            debt_engine: @0x0,
            use_external_engine: false,
            debt_info_legacy: string::utf8(b""),
            credit_events_legacy: string::utf8(b""),
        }
    }

    /// Initialize debt state with identifier
    public fun init_debt_state_with_identifier(
        identifier: DebtIdentifier,
        ctx: &mut TxContext
    ): DebtState {
        DebtState {
            id: object::new(ctx),
            identifier,
            instrument: init_debt_instrument(),
            terms: init_bond_terms(),
            credit_events: init_credit_events(),
            debt_engine: @0x0,
            use_external_engine: false,
            debt_info_legacy: string::utf8(b""),
            credit_events_legacy: string::utf8(b""),
        }
    }

    /// Initialize debt state with full instrument data
    public fun init_debt_state_full(
        identifier: DebtIdentifier,
        instrument: DebtInstrument,
        terms: BondTerms,
        ctx: &mut TxContext
    ): DebtState {
        DebtState {
            id: object::new(ctx),
            identifier,
            instrument,
            terms,
            credit_events: init_credit_events(),
            debt_engine: @0x0,
            use_external_engine: false,
            debt_info_legacy: string::utf8(b""),
            credit_events_legacy: string::utf8(b""),
        }
    }

    /// Initialize empty DebtIdentifier
    public fun init_debt_identifier(): DebtIdentifier {
        DebtIdentifier {
            issuer_name: string::utf8(b""),
            issuer_description: string::utf8(b""),
            guarantor: string::utf8(b""),
            debt_holder_representative: string::utf8(b""),
            isin: string::utf8(b""),
        }
    }

    /// Initialize empty DebtInstrument
    public fun init_debt_instrument(): DebtInstrument {
        DebtInstrument {
            interest_rate: 0,
            par_value: 0,
            minimum_denomination: 0,
            issuance_date: 0,
            maturity_date: 0,
            coupon_frequency: string::utf8(b""),
            interest_schedule_format: string::utf8(b""),
            interest_payment_date: string::utf8(b""),
            day_count_convention: DayCountConvention::ActualActual,
            business_day_convention: BusinessDayConvention::Unadjusted,
            currency: string::utf8(b""),
            currency_contract: @0x0,
        }
    }

    /// Initialize empty CreditEvents
    public fun init_credit_events(): CreditEvents {
        CreditEvents {
            flag_default: false,
            flag_redeemed: false,
            flag_matured: false,
            rating: string::utf8(b""),
            principal_distributed: 0,
            next_coupon_date: 0,
        }
    }

    /// Initialize empty BondTerms
    public fun init_bond_terms(): BondTerms {
        BondTerms {
            call_schedule: string::utf8(b""),
            put_schedule: string::utf8(b""),
            sinking_fund_schedule: string::utf8(b""),
            convertible_terms: string::utf8(b""),
            collateral_description: string::utf8(b""),
        }
    }

    // ========== DEBTIDENTIFIER GETTERS ==========
    
    public fun get_issuer_name(state: &DebtState): String { state.identifier.issuer_name }
    public fun get_issuer_description(state: &DebtState): String { state.identifier.issuer_description }
    public fun get_guarantor(state: &DebtState): String { state.identifier.guarantor }
    public fun get_debt_holder_representative(state: &DebtState): String { state.identifier.debt_holder_representative }
    public fun get_isin(state: &DebtState): String { state.identifier.isin }

    // ========== DEBTINSTRUMENT GETTERS ==========
    
    public fun get_interest_rate(state: &DebtState): u64 { state.instrument.interest_rate }
    public fun get_par_value(state: &DebtState): u64 { state.instrument.par_value }
    public fun get_minimum_denomination(state: &DebtState): u64 { state.instrument.minimum_denomination }
    public fun get_issuance_date(state: &DebtState): u64 { state.instrument.issuance_date }
    public fun get_maturity_date(state: &DebtState): u64 { state.instrument.maturity_date }
    public fun get_coupon_frequency(state: &DebtState): String { state.instrument.coupon_frequency }
    public fun get_interest_schedule_format(state: &DebtState): String { state.instrument.interest_schedule_format }
    public fun get_interest_payment_date(state: &DebtState): String { state.instrument.interest_payment_date }
    public fun get_day_count_convention(state: &DebtState): DayCountConvention { state.instrument.day_count_convention }
    public fun get_business_day_convention(state: &DebtState): BusinessDayConvention { state.instrument.business_day_convention }
    public fun get_currency(state: &DebtState): String { state.instrument.currency }
    public fun get_currency_contract(state: &DebtState): address { state.instrument.currency_contract }

    // ========== CREDITEVENTS GETTERS ==========
    
    public fun is_default(state: &DebtState): bool { state.credit_events.flag_default }
    public fun is_redeemed(state: &DebtState): bool { state.credit_events.flag_redeemed }
    public fun is_matured(state: &DebtState): bool { state.credit_events.flag_matured }
    public fun get_rating(state: &DebtState): String { state.credit_events.rating }
    public fun get_principal_distributed(state: &DebtState): u64 { state.credit_events.principal_distributed }
    public fun get_next_coupon_date(state: &DebtState): u64 { state.credit_events.next_coupon_date }

    // ========== BONDTERMS GETTERS ==========
    
    public fun get_call_schedule(state: &DebtState): String { state.terms.call_schedule }
    public fun get_put_schedule(state: &DebtState): String { state.terms.put_schedule }
    public fun get_sinking_fund_schedule(state: &DebtState): String { state.terms.sinking_fund_schedule }
    public fun get_convertible_terms(state: &DebtState): String { state.terms.convertible_terms }
    public fun get_collateral_description(state: &DebtState): String { state.terms.collateral_description }

    // ========== DEBTENGINE GETTERS ==========
    
    public fun get_debt_engine(state: &DebtState): address { state.debt_engine }
    public fun is_external_engine_enabled(state: &DebtState): bool { state.use_external_engine }

    // ========== LEGACY GETTERS (Backward Compatibility) ==========
    
    public fun get_debt(state: &DebtState): String { state.debt_info_legacy }
    public fun get_credit_events_legacy(state: &DebtState): String { state.credit_events_legacy }
    public fun is_default_flagged(state: &DebtState): bool { state.credit_events.flag_default }

    // ========== DIRECT CREDITEVENTS GETTERS ==========
    /// Getters for CreditEvents struct (for external modules)
    
    public fun get_credit_events(state: &DebtState): CreditEvents {
        state.credit_events
    }

    public fun credit_events_is_default(events: &CreditEvents): bool { events.flag_default }
    public fun credit_events_is_redeemed(events: &CreditEvents): bool { events.flag_redeemed }
    public fun credit_events_is_matured(events: &CreditEvents): bool { events.flag_matured }
    public fun credit_events_get_rating(events: &CreditEvents): String { events.rating }
    public fun credit_events_get_principal_distributed(events: &CreditEvents): u64 { events.principal_distributed }
    public fun credit_events_get_next_coupon_date(events: &CreditEvents): u64 { events.next_coupon_date }

    // ========== DIRECT DEBTIDENTIFIER GETTERS ==========
    /// Getters for DebtIdentifier struct (for external modules)
    
    public fun identifier_get_issuer_name(id: &DebtIdentifier): String { id.issuer_name }
    public fun identifier_get_isin(id: &DebtIdentifier): String { id.isin }

    // ========== DIRECT DEBTINSTRUMENT GETTERS ==========
    /// Getters for DebtInstrument struct (for external modules)
    
    public fun instrument_get_interest_rate(inst: &DebtInstrument): u64 { inst.interest_rate }
    public fun instrument_get_maturity_date(inst: &DebtInstrument): u64 { inst.maturity_date }
    public fun instrument_get_par_value(inst: &DebtInstrument): u64 { inst.par_value }

    // ========== CREDITEVENTS SETTERS (Direct) ==========
    /// Setters for CreditEvents struct (for external modules)
    
    public fun credit_events_flag_default(events: &mut CreditEvents) {
        events.flag_default = true;
    }
    
    public fun credit_events_clear_default(events: &mut CreditEvents) {
        events.flag_default = false;
    }
    
    public fun credit_events_flag_redeemed(events: &mut CreditEvents) {
        events.flag_redeemed = true;
    }
    
    public fun credit_events_flag_matured(events: &mut CreditEvents) {
        events.flag_matured = true;
    }
    
    public fun credit_events_set_rating(events: &mut CreditEvents, rating: String) {
        events.rating = rating;
    }
    
    public fun credit_events_record_principal(events: &mut CreditEvents, amount: u64) {
        events.principal_distributed = events.principal_distributed + amount;
    }

    // ========== DEBTIDENTIFIER SETTERS ==========
    
    public fun set_debt_identifier(state: &mut DebtState, identifier: DebtIdentifier) {
        state.identifier = identifier;
    }

    public fun set_issuer_name(state: &mut DebtState, name: String) {
        state.identifier.issuer_name = name;
    }

    public fun set_issuer_description(state: &mut DebtState, description: String) {
        state.identifier.issuer_description = description;
    }

    public fun set_guarantor(state: &mut DebtState, guarantor: String) {
        state.identifier.guarantor = guarantor;
    }

    public fun set_debt_holder_representative(state: &mut DebtState, representative: String) {
        state.identifier.debt_holder_representative = representative;
    }

    public fun set_isin(state: &mut DebtState, isin: String) {
        state.identifier.isin = isin;
    }

    // ========== DEBTINSTRUMENT SETTERS ==========
    
    public fun set_debt_instrument(state: &mut DebtState, instrument: DebtInstrument) {
        state.instrument = instrument;
    }

    public fun set_interest_rate(state: &mut DebtState, rate: u64) {
        state.instrument.interest_rate = rate;
    }

    public fun set_par_value(state: &mut DebtState, value: u64) {
        state.instrument.par_value = value;
    }

    public fun set_minimum_denomination(state: &mut DebtState, min: u64) {
        state.instrument.minimum_denomination = min;
    }

    public fun set_issuance_date(state: &mut DebtState, date: u64) {
        state.instrument.issuance_date = date;
    }

    public fun set_maturity_date(state: &mut DebtState, date: u64) {
        state.instrument.maturity_date = date;
    }

    public fun set_coupon_frequency(state: &mut DebtState, frequency: String) {
        state.instrument.coupon_frequency = frequency;
    }

    public fun set_interest_schedule_format(state: &mut DebtState, format: String) {
        state.instrument.interest_schedule_format = format;
    }

    public fun set_interest_payment_date(state: &mut DebtState, date: String) {
        state.instrument.interest_payment_date = date;
    }

    public fun set_day_count_convention(state: &mut DebtState, convention: DayCountConvention) {
        state.instrument.day_count_convention = convention;
    }

    public fun set_business_day_convention(state: &mut DebtState, convention: BusinessDayConvention) {
        state.instrument.business_day_convention = convention;
    }

    public fun set_currency(state: &mut DebtState, currency: String) {
        state.instrument.currency = currency;
    }

    public fun set_currency_contract(state: &mut DebtState, contract: address) {
        state.instrument.currency_contract = contract;
    }

    // ========== CREDITEVENTS SETTERS ==========
    
    public fun set_credit_events(state: &mut DebtState, events: CreditEvents) {
        state.credit_events = events;
    }

    public fun flag_default(state: &mut DebtState) {
        state.credit_events.flag_default = true;
    }

    public fun clear_default(state: &mut DebtState) {
        state.credit_events.flag_default = false;
    }

    public fun flag_redeemed(state: &mut DebtState) {
        state.credit_events.flag_redeemed = true;
    }

    public fun flag_matured(state: &mut DebtState) {
        state.credit_events.flag_matured = true;
    }

    public fun set_rating(state: &mut DebtState, rating: String) {
        state.credit_events.rating = rating;
    }

    public fun record_principal_distribution(state: &mut DebtState, amount: u64) {
        state.credit_events.principal_distributed = state.credit_events.principal_distributed + amount;
    }

    public fun set_next_coupon_date(state: &mut DebtState, date: u64) {
        state.credit_events.next_coupon_date = date;
    }

    // ========== BONDTERMS SETTERS ==========
    
    public fun set_bond_terms(state: &mut DebtState, terms: BondTerms) {
        state.terms = terms;
    }

    public fun set_call_schedule(state: &mut DebtState, schedule: String) {
        state.terms.call_schedule = schedule;
    }

    public fun set_put_schedule(state: &mut DebtState, schedule: String) {
        state.terms.put_schedule = schedule;
    }

    public fun set_sinking_fund_schedule(state: &mut DebtState, schedule: String) {
        state.terms.sinking_fund_schedule = schedule;
    }

    public fun set_convertible_terms(state: &mut DebtState, terms: String) {
        state.terms.convertible_terms = terms;
    }

    public fun set_collateral_description(state: &mut DebtState, description: String) {
        state.terms.collateral_description = description;
    }

    // ========== DEBTENGINE SETTERS ==========
    
    public fun set_debt_engine(state: &mut DebtState, engine: address) {
        state.debt_engine = engine;
    }

    public fun enable_external_engine(state: &mut DebtState) {
        state.use_external_engine = true;
    }

    public fun disable_external_engine(state: &mut DebtState) {
        state.use_external_engine = false;
    }

    // ========== LEGACY SETTERS (Backward Compatibility) ==========
    
    public fun set_debt(state: &mut DebtState, debt_info: String) {
        state.debt_info_legacy = debt_info;
    }

    public fun set_credit_events_legacy(state: &mut DebtState, events: String) {
        state.credit_events_legacy = events;
    }

    // ========== VALIDATION FUNCTIONS ==========
    
    /// Require debt is not in default
    public fun require_not_in_default(state: &DebtState) {
        assert!(!state.credit_events.flag_default, EDebtInDefault);
    }

    /// Require debt is not fully redeemed
    public fun require_not_redeemed(state: &DebtState) {
        assert!(!state.credit_events.flag_redeemed, EAlreadyRedeemed);
    }

    /// Validate minimum denomination for transfers
    public fun validate_minimum_denomination(state: &DebtState, amount: u64): bool {
        if (state.instrument.minimum_denomination == 0) {
            return true
        };
        amount % state.instrument.minimum_denomination == 0
    }

    /// Require valid minimum denomination
    public fun require_valid_minimum_denomination(state: &DebtState, amount: u64) {
        assert!(validate_minimum_denomination(state, amount), EInvalidDenomination);
    }

    /// Check if bond has reached maturity
    public fun is_matured_at_time(current_time: u64, state: &DebtState): bool {
        if (state.instrument.maturity_date == 0) {
            return false
        };
        current_time >= state.instrument.maturity_date
    }

    /// Check if redemption is allowed (matured but not fully redeemed)
    public fun is_redemption_allowed(current_time: u64, state: &DebtState): bool {
        is_matured_at_time(current_time, state) && !state.credit_events.flag_redeemed
    }

    /// Check if bond is fully redeemed
    public fun is_fully_redeemed(state: &DebtState): bool {
        state.credit_events.flag_redeemed
    }

    /// Calculate time to maturity (returns 0 if already matured)
    public fun time_to_maturity(current_time: u64, state: &DebtState): u64 {
        if (current_time >= state.instrument.maturity_date) {
            return 0
        };
        state.instrument.maturity_date - current_time
    }

    /// Check maturity and update state if needed
    public fun check_and_update_maturity(state: &mut DebtState, current_time: u64) {
        if (!state.credit_events.flag_matured && is_matured_at_time(current_time, state)) {
            state.credit_events.flag_matured = true;
        }
    }

    /// Validate redemption amount against remaining principal
    public fun validate_redemption_amount(state: &DebtState, amount: u64): bool {
        // For now, just check denomination
        // Future: track total supply vs redeemed amount
        validate_minimum_denomination(state, amount)
    }

    // ========== INTEREST CALCULATION HELPERS ==========
    
    /// Get interest rate multiplier constant
    public fun interest_rate_multiplier(): u64 { INTEREST_RATE_MULTIPLIER }

    /// Convert fixed-point rate to percentage (for display)
    /// e.g., 5250000 -> 5.25
    public fun rate_to_percentage(rate_fixed_point: u64): u64 {
        rate_fixed_point / (INTEREST_RATE_MULTIPLIER / 100)
    }

    /// Convert percentage to fixed-point rate
    /// e.g., 5.25 -> 5250000
    public fun percentage_to_rate(percentage: u64): u64 {
        percentage * (INTEREST_RATE_MULTIPLIER / 100)
    }

    /// Calculate simple interest
    /// Formula: principal * rate * (days_numerator / days_denominator)
    /// Returns interest amount in base units
    public fun calculate_simple_interest(
        principal: u64,
        rate_fixed_point: u64,
        days_numerator: u64,
        days_denominator: u64
    ): u64 {
        // Avoid division by zero
        if (days_denominator == 0 || principal == 0 || rate_fixed_point == 0) {
            return 0
        };
        
        // Calculate: principal * rate * days / (multiplier * total_days)
        let principal_times_rate = (principal as u128) * (rate_fixed_point as u128);
        let interest = principal_times_rate * (days_numerator as u128);
        let denominator = (INTEREST_RATE_MULTIPLIER as u128) * (days_denominator as u128);
        
        ((interest / denominator) as u64)
    }

    // ========== DAY COUNT HELPERS ==========
    
    /// Get days in year for given convention
    public fun days_in_year(convention: &DayCountConvention): u64 {
        match (convention) {
            DayCountConvention::Thirty360 => DAYS_360,
            DayCountConvention::Actual360 => DAYS_360,
            DayCountConvention::Actual365 => DAYS_365,
            DayCountConvention::ActualActual => DAYS_365, // Simplified
        }
    }

    // ========== CONSTRUCTOR HELPERS ==========
    
    /// Create DebtIdentifier with all fields
    public fun create_debt_identifier(
        issuer_name: String,
        issuer_description: String,
        guarantor: String,
        debt_holder_representative: String,
        isin: String
    ): DebtIdentifier {
        DebtIdentifier {
            issuer_name,
            issuer_description,
            guarantor,
            debt_holder_representative,
            isin,
        }
    }

    /// Create DebtInstrument with all fields
    public fun create_debt_instrument(
        interest_rate: u64,
        par_value: u64,
        minimum_denomination: u64,
        issuance_date: u64,
        maturity_date: u64,
        coupon_frequency: String,
        interest_schedule_format: String,
        interest_payment_date: String,
        day_count_convention: DayCountConvention,
        business_day_convention: BusinessDayConvention,
        currency: String,
        currency_contract: address
    ): DebtInstrument {
        DebtInstrument {
            interest_rate,
            par_value,
            minimum_denomination,
            issuance_date,
            maturity_date,
            coupon_frequency,
            interest_schedule_format,
            interest_payment_date,
            day_count_convention,
            business_day_convention,
            currency,
            currency_contract,
        }
    }

    /// Create CreditEvents with all fields
    public fun create_credit_events(
        flag_default: bool,
        flag_redeemed: bool,
        flag_matured: bool,
        rating: String,
        principal_distributed: u64,
        next_coupon_date: u64
    ): CreditEvents {
        CreditEvents {
            flag_default,
            flag_redeemed,
            flag_matured,
            rating,
            principal_distributed,
            next_coupon_date,
        }
    }

    /// Create BondTerms with all fields
    public fun create_bond_terms(
        call_schedule: String,
        put_schedule: String,
        sinking_fund_schedule: String,
        convertible_terms: String,
        collateral_description: String
    ): BondTerms {
        BondTerms {
            call_schedule,
            put_schedule,
            sinking_fund_schedule,
            convertible_terms,
            collateral_description,
        }
    }
}
