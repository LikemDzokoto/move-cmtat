/// Interest Engine - Coupon Schedule & Payment Tracking
/// Manages coupon schedules, interest calculations, and payment history
/// Supports various payment frequencies and calculation methods
#[allow(unused_field, unused_const)]
module move_cmtat::interest_engine {
    use std::string::{Self, String};
    use iota::table::{Self, Table};
    use iota::event;

    // ========== CONSTANTS ==========
    
    /// Fixed-point multiplier for interest rates
    const INTEREST_RATE_MULTIPLIER: u64 = 1_000_000;
    
    /// Seconds in a day
    const SECONDS_PER_DAY: u64 = 86400;
    
    /// Days in periods (approximate for schedule generation)
    const DAYS_ANNUAL: u64 = 365;
    const DAYS_SEMI_ANNUAL: u64 = 182;
    const DAYS_QUARTERLY: u64 = 91;
    const DAYS_MONTHLY: u64 = 30;

    // ========== ERRORS ==========
    
    const ECouponNotFound: u64 = 800;
    const EInvalidCouponNumber: u64 = 801;
    const ECouponAlreadyPaid: u64 = 802;
    const EInvalidPaymentDate: u64 = 803;
    const EScheduleAlreadyGenerated: u64 = 804;
    const EInvalidFrequency: u64 = 805;
    const ECouponNotDue: u64 = 806;
    const EInvalidPrincipal: u64 = 807;
    const EInvalidRate: u64 = 808;

    // ========== STRUCTS ==========
    
    /// Individual coupon payment
    public struct CouponPayment has copy, drop, store {
        coupon_number: u64,               // Sequential number (1, 2, 3...)
        payment_date: u64,                // Scheduled payment date (Unix seconds)
        record_date: u64,                 // Record date for eligibility
        amount_per_bond: u64,             // Interest per bond unit
        total_amount: u64,                // Total interest for all bonds
        principal_at_record: u64,         // Total supply at record date
        paid: bool,                       // Payment status
        actual_payment_date: Option<u64>, // When actually paid
        payment_tx: Option<address>,      // Transaction reference
    }

    // ========== GETTERS ==========

    public fun coupon_get_number(coupon: &CouponPayment): u64 { coupon.coupon_number }
    public fun coupon_get_payment_date(coupon: &CouponPayment): u64 { coupon.payment_date }
    public fun coupon_get_record_date(coupon: &CouponPayment): u64 { coupon.record_date }
    public fun coupon_get_amount_per_bond(coupon: &CouponPayment): u64 { coupon.amount_per_bond }
    public fun coupon_get_total_amount(coupon: &CouponPayment): u64 { coupon.total_amount }
    public fun coupon_get_principal_at_record(coupon: &CouponPayment): u64 { coupon.principal_at_record }
    public fun coupon_is_paid(coupon: &CouponPayment): bool { coupon.paid }
    public fun coupon_get_actual_payment_date(coupon: &CouponPayment): Option<u64> { coupon.actual_payment_date }
    public fun coupon_get_payment_tx(coupon: &CouponPayment): Option<address> { coupon.payment_tx }

    /// Coupon schedule
    public struct CouponSchedule has copy, drop, store {
        payments: vector<CouponPayment>,
        total_coupons: u64,
        coupons_paid: u64,
        next_coupon_number: u64,
        first_payment_date: u64,
        last_payment_date: u64,
        schedule_generated: bool,
    }

    /// Interest engine state
    public struct InterestEngineState has key, store {
        id: UID,
        schedule: CouponSchedule,
        payment_history: Table<u64, CouponPayment>,  // coupon_number -> CouponPayment
        total_interest_paid: u64,
        total_interest_accrued: u64,
        last_calculation_time: u64,
    }

    // ========== EVENTS ==========
    
    public struct ScheduleCreated has copy, drop {
        total_coupons: u64,
        first_payment_date: u64,
        last_payment_date: u64,
        coupon_frequency: String,
        generated_by: address,
    }

    public struct CouponScheduled has copy, drop {
        coupon_number: u64,
        payment_date: u64,
        record_date: u64,
        amount_per_bond: u64,
        total_amount: u64,
    }

    public struct CouponPaid has copy, drop {
        coupon_number: u64,
        payment_date: u64,
        actual_payment_date: u64,
        total_amount: u64,
        paid_by: address,
    }

    public struct CouponPaymentFailed has copy, drop {
        _coupon_number: u64,
        _scheduled_date: u64,
        _reason: String,
        _attempted_by: address,
    }

    public struct InterestAccrued has copy, drop {
        _amount: u64,
        _from_time: u64,
        _to_time: u64,
        _calculated_by: address,
    }

    // ========== INITIALIZATION ==========
    
    /// Initialize empty interest engine
    public fun init_interest_engine(ctx: &mut TxContext): InterestEngineState {
        InterestEngineState {
            id: object::new(ctx),
            schedule: init_empty_schedule(),
            payment_history: table::new(ctx),
            total_interest_paid: 0,
            total_interest_accrued: 0,
            last_calculation_time: 0,
        }
    }

    /// Initialize empty coupon schedule
    fun init_empty_schedule(): CouponSchedule {
        CouponSchedule {
            payments: vector::empty(),
            total_coupons: 0,
            coupons_paid: 0,
            next_coupon_number: 1,
            first_payment_date: 0,
            last_payment_date: 0,
            schedule_generated: false,
        }
    }

    // ========== SCHEDULE GENERATION ==========
    
    /// Generate coupon schedule from bond parameters
    public fun generate_coupon_schedule(
        state: &mut InterestEngineState,
        issuance_date: u64,
        maturity_date: u64,
        frequency: String,
        rate_fixed_point: u64,
        par_value: u64,
        total_supply: u64,
        day_count_convention: u8,  // 0=30/360, 1=Actual/360, 2=Actual/365, 3=Actual/Actual
        _ctx: &mut TxContext
    ) {
        // Validate not already generated
        assert!(!state.schedule.schedule_generated, EScheduleAlreadyGenerated);
        assert!(maturity_date > issuance_date, EInvalidPaymentDate);
        assert!(rate_fixed_point > 0, EInvalidRate);
        assert!(par_value > 0, EInvalidPrincipal);

        // Calculate period length in seconds
        let period_seconds = frequency_to_seconds(&frequency);
        assert!(period_seconds > 0, EInvalidFrequency);

        // Calculate number of coupons
        let total_duration = maturity_date - issuance_date;
        let mut num_coupons = total_duration / period_seconds;
        if (total_duration % period_seconds > 0) {
            num_coupons = num_coupons + 1;
        };

        // Generate coupon payments
        let mut payments = vector::empty<CouponPayment>();
        let mut current_date = issuance_date + period_seconds;
        let mut coupon_num = 1;

        while (coupon_num <= num_coupons && current_date <= maturity_date) {
            // Calculate coupon amount
            let amount_per_bond = calculate_coupon_amount(
                par_value,
                rate_fixed_point,
                period_seconds,
                day_count_convention
            );
            
            let total_amount = amount_per_bond * total_supply;
            let record_date = current_date - SECONDS_PER_DAY; // 1 day before payment

            let payment = CouponPayment {
                coupon_number: coupon_num,
                payment_date: current_date,
                record_date: record_date,
                amount_per_bond,
                total_amount,
                principal_at_record: total_supply,
                paid: false,
                actual_payment_date: option::none(),
                payment_tx: option::none(),
            };

            vector::push_back(&mut payments, payment);

            // Store in history
            table::add(&mut state.payment_history, coupon_num, payment);

            // Emit event
            event::emit(CouponScheduled {
                coupon_number: coupon_num,
                payment_date: current_date,
                record_date,
                amount_per_bond,
                total_amount,
            });

            current_date = current_date + period_seconds;
            coupon_num = coupon_num + 1;
        };

        // Update schedule
        state.schedule = CouponSchedule {
            payments,
            total_coupons: num_coupons,
            coupons_paid: 0,
            next_coupon_number: 1,
            first_payment_date: issuance_date + period_seconds,
            last_payment_date: current_date - period_seconds,
            schedule_generated: true,
        };

        state.last_calculation_time = issuance_date;

        // Emit schedule created event
        event::emit(ScheduleCreated {
            total_coupons: num_coupons,
            first_payment_date: state.schedule.first_payment_date,
            last_payment_date: state.schedule.last_payment_date,
            coupon_frequency: frequency,
            generated_by: tx_context::sender(_ctx),
        });
    }

    // ========== COUPON MANAGEMENT ==========
    
    /// Get next unpaid coupon
    public fun get_next_coupon(state: &InterestEngineState): Option<CouponPayment> {
        if (!state.schedule.schedule_generated) {
            return option::none()
        };

        let next_num = state.schedule.next_coupon_number;
        if (next_num > state.schedule.total_coupons) {
            return option::none()
        };

        option::some(*vector::borrow(&state.schedule.payments, next_num - 1))
    }

    /// Get specific coupon by number
    public fun get_coupon(state: &InterestEngineState, coupon_number: u64): CouponPayment {
        assert!(coupon_number > 0 && coupon_number <= state.schedule.total_coupons, EInvalidCouponNumber);
        *vector::borrow(&state.schedule.payments, coupon_number - 1)
    }

    /// Check if coupon exists
    public fun coupon_exists(state: &InterestEngineState, coupon_number: u64): bool {
        coupon_number > 0 && coupon_number <= state.schedule.total_coupons
    }

    /// Get all upcoming coupons
    public fun get_upcoming_coupons(
        state: &InterestEngineState,
        current_time: u64
    ): vector<CouponPayment> {
        let mut upcoming = vector::empty<CouponPayment>();
        
        if (!state.schedule.schedule_generated) {
            return upcoming
        };

        let mut i = state.schedule.next_coupon_number;
        while (i <= state.schedule.total_coupons) {
            let coupon = get_coupon(state, i);
            if (coupon.payment_date >= current_time) {
                vector::push_back(&mut upcoming, coupon);
            };
            i = i + 1;
        };

        upcoming
    }

    /// Get all unpaid coupons
    public fun get_unpaid_coupons(state: &InterestEngineState): vector<CouponPayment> {
        let mut unpaid = vector::empty<CouponPayment>();
        
        if (!state.schedule.schedule_generated) {
            return unpaid
        };

        let mut i = state.schedule.next_coupon_number;
        while (i <= state.schedule.total_coupons) {
            let coupon = get_coupon(state, i);
            if (!coupon.paid) {
                vector::push_back(&mut unpaid, coupon);
            };
            i = i + 1;
        };

        unpaid
    }

    /// Get paid coupons
    public fun get_paid_coupons(state: &InterestEngineState): vector<CouponPayment> {
        let mut paid = vector::empty<CouponPayment>();
        
        if (!state.schedule.schedule_generated || state.schedule.coupons_paid == 0) {
            return paid
        };

        let mut i = 1;
        while (i < state.schedule.next_coupon_number) {
            let coupon = get_coupon(state, i);
            if (coupon.paid) {
                vector::push_back(&mut paid, coupon);
            };
            i = i + 1;
        };

        paid
    }

    // ========== PAYMENT PROCESSING ==========
    
    /// Record coupon payment
    public fun record_coupon_payment(
        state: &mut InterestEngineState,
        coupon_number: u64,
        actual_payment_date: u64,
        ctx: &TxContext
    ) {
        assert!(coupon_exists(state, coupon_number), ECouponNotFound);
        
        let mut coupon = get_coupon(state, coupon_number);
        assert!(!coupon.paid, ECouponAlreadyPaid);
        assert!(actual_payment_date >= coupon.payment_date, ECouponNotDue);

        // Update coupon
        coupon.paid = true;
        coupon.actual_payment_date = option::some(actual_payment_date);
        coupon.payment_tx = option::some(tx_context::sender(ctx));

        // Update in schedule
        let idx = coupon_number - 1;
        *vector::borrow_mut(&mut state.schedule.payments, idx) = coupon;

        // Update in history
        *table::borrow_mut(&mut state.payment_history, coupon_number) = coupon;

        // Update totals
        state.schedule.coupons_paid = state.schedule.coupons_paid + 1;
        if (state.schedule.next_coupon_number == coupon_number) {
            state.schedule.next_coupon_number = coupon_number + 1;
        };
        state.total_interest_paid = state.total_interest_paid + coupon.total_amount;

        // Emit event
        event::emit(CouponPaid {
            coupon_number,
            payment_date: coupon.payment_date,
            actual_payment_date,
            total_amount: coupon.total_amount,
            paid_by: tx_context::sender(ctx),
        });
    }

    /// Batch record payments
    public fun batch_record_payments(
        state: &mut InterestEngineState,
        coupon_numbers: vector<u64>,
        actual_payment_date: u64,
        ctx: &TxContext
    ) {
        let len = vector::length(&coupon_numbers);
        let mut i = 0;
        
        while (i < len) {
            let coupon_number = *vector::borrow(&coupon_numbers, i);
            if (coupon_exists(state, coupon_number)) {
                let coupon = get_coupon(state, coupon_number);
                if (!coupon.paid) {
                    record_coupon_payment(state, coupon_number, actual_payment_date, ctx);
                }
            };
            i = i + 1;
        }
    }

    /// Check if coupon is due for payment
    public fun is_coupon_due(
        state: &InterestEngineState,
        coupon_number: u64,
        current_time: u64
    ): bool {
        if (!coupon_exists(state, coupon_number)) {
            return false
        };

        let coupon = get_coupon(state, coupon_number);
        !coupon.paid && current_time >= coupon.payment_date
    }

    /// Get next due coupon
    public fun get_next_due_coupon(
        state: &InterestEngineState,
        current_time: u64
    ): Option<CouponPayment> {
        if (!state.schedule.schedule_generated) {
            return option::none()
        };

        let mut i = state.schedule.next_coupon_number;
        while (i <= state.schedule.total_coupons) {
            let coupon = get_coupon(state, i);
            if (!coupon.paid && current_time >= coupon.payment_date) {
                return option::some(coupon)
            };
            i = i + 1;
        };

        option::none()
    }

    // ========== INTEREST CALCULATIONS ==========
    
    /// Get total interest accrued to date
    public fun get_total_interest_accrued(
        state: &InterestEngineState,
        current_time: u64
    ): u64 {
        if (!state.schedule.schedule_generated) {
            return 0
        };

        let mut accrued = state.total_interest_paid;

        // Add interest for due but unpaid coupons
        let mut i = state.schedule.next_coupon_number;
        while (i <= state.schedule.total_coupons) {
            let coupon = get_coupon(state, i);
            if (current_time >= coupon.payment_date && !coupon.paid) {
                accrued = accrued + coupon.total_amount;
            };
            i = i + 1;
        };

        accrued
    }

    /// Calculate interest accrued between two coupons
    public fun calculate_interest_between_coupons(
        state: &InterestEngineState,
        start_coupon: u64,
        end_coupon: u64
    ): u64 {
        assert!(start_coupon <= end_coupon, EInvalidCouponNumber);
        assert!(end_coupon <= state.schedule.total_coupons, EInvalidCouponNumber);

        let mut total = 0;
        let mut i = start_coupon;
        
        while (i <= end_coupon) {
            let coupon = get_coupon(state, i);
            total = total + coupon.total_amount;
            i = i + 1;
        };

        total
    }

    /// Calculate interest per account based on balance
    public fun calculate_account_interest(
        state: &InterestEngineState,
        coupon_number: u64,
        account_balance: u64
    ): u64 {
        assert!(coupon_exists(state, coupon_number), ECouponNotFound);

        let coupon = get_coupon(state, coupon_number);
        if (coupon.principal_at_record == 0) {
            return 0
        };

        // Proportional share: (account_balance / total_supply) * coupon_amount
        let share = (account_balance as u128) * (coupon.total_amount as u128);
        ((share / (coupon.principal_at_record as u128)) as u64)
    }

    // ========== QUERIES ==========
    
    /// Get total coupons scheduled
    public fun get_total_coupons(state: &InterestEngineState): u64 {
        state.schedule.total_coupons
    }

    /// Get number of coupons paid
    public fun get_coupons_paid(state: &InterestEngineState): u64 {
        state.schedule.coupons_paid
    }

    /// Get number of coupons remaining
    public fun get_coupons_remaining(state: &InterestEngineState): u64 {
        state.schedule.total_coupons - state.schedule.coupons_paid
    }

    /// Get total interest paid to date
    public fun get_total_interest_paid(state: &InterestEngineState): u64 {
        state.total_interest_paid
    }

    /// Get first payment date
    public fun get_first_payment_date(state: &InterestEngineState): u64 {
        state.schedule.first_payment_date
    }

    /// Get last payment date
    public fun get_last_payment_date(state: &InterestEngineState): u64 {
        state.schedule.last_payment_date
    }

    /// Check if schedule is generated
    public fun is_schedule_generated(state: &InterestEngineState): bool {
        state.schedule.schedule_generated
    }

    /// Get next coupon number
    public fun get_next_coupon_number(state: &InterestEngineState): u64 {
        state.schedule.next_coupon_number
    }

    /// Get payment history reference
    public fun get_payment_history(state: &InterestEngineState): &Table<u64, CouponPayment> {
        &state.payment_history
    }

    /// Check if all coupons are paid
    public fun are_all_coupons_paid(state: &InterestEngineState): bool {
        state.schedule.coupons_paid >= state.schedule.total_coupons && 
        state.schedule.total_coupons > 0
    }

    /// Get estimated total interest over bond life
    public fun get_estimated_total_interest(state: &InterestEngineState): u64 {
        if (!state.schedule.schedule_generated) {
            return 0
        };

        let mut total = 0;
        let mut i = 1;
        
        while (i <= state.schedule.total_coupons) {
            let coupon = get_coupon(state, i);
            total = total + coupon.total_amount;
            i = i + 1;
        };

        total
    }

    // ========== HELPER FUNCTIONS ==========
    
    /// Convert frequency string to seconds
    fun frequency_to_seconds(frequency: &String): u64 {
        let freq_copy = *frequency;
        let freq_upper = string::to_ascii(freq_copy);
        let freq_bytes = std::ascii::as_bytes(&freq_upper);
        
        let annual = b"ANNUAL";
        let yearly = b"YEARLY";
        let semi = b"SEMI";
        let half = b"HALF";
        let quarter = b"QUARTER";
        let month = b"MONTH";
        
        if (is_substring(freq_bytes, &annual) || is_substring(freq_bytes, &yearly)) {
            DAYS_ANNUAL * SECONDS_PER_DAY
        } else if (is_substring(freq_bytes, &semi) || is_substring(freq_bytes, &half)) {
            DAYS_SEMI_ANNUAL * SECONDS_PER_DAY
        } else if (is_substring(freq_bytes, &quarter)) {
            DAYS_QUARTERLY * SECONDS_PER_DAY
        } else if (is_substring(freq_bytes, &month)) {
            DAYS_MONTHLY * SECONDS_PER_DAY
        } else {
            0 // Invalid
        }
    }

    /// Calculate coupon amount for a period
    fun calculate_coupon_amount(
        principal: u64,
        rate_fixed_point: u64,
        period_seconds: u64,
        day_count_convention: u8
    ): u64 {
        let period_days = period_seconds / SECONDS_PER_DAY;
        let year_days = if (day_count_convention == 0) {
            360u64 // 30/360
        } else if (day_count_convention == 1) {
            360u64 // Actual/360
        } else if (day_count_convention == 2) {
            365u64 // Actual/365
        } else {
            365u64 // Actual/Actual (simplified)
        };

        // Calculate: principal * rate * period_days / (multiplier * year_days)
        let principal_rate = (principal as u128) * (rate_fixed_point as u128);
        let interest = principal_rate * (period_days as u128);
        let denominator = (INTEREST_RATE_MULTIPLIER as u128) * (year_days as u128);
        
        ((interest / denominator) as u64)
    }

    /// Check if bytes contain substring
    fun is_substring(bytes: &vector<u8>, pattern: &vector<u8>): bool {
        let bytes_len = vector::length(bytes);
        let pattern_len = vector::length(pattern);
        
        if (pattern_len == 0 || bytes_len < pattern_len) {
            return false
        };

        let mut i = 0;
        while (i <= bytes_len - pattern_len) {
            let mut j = 0;
            let mut matched = true;
            
            while (j < pattern_len) {
                if (*vector::borrow(bytes, i + j) != *vector::borrow(pattern, j)) {
                    matched = false;
                    break
                };
                j = j + 1;  
            };
            
            if (matched) {
                return true
            };
            i = i + 1;
        };

        false
    }

    /// Create coupon payment struct
    public fun create_coupon_payment(
        coupon_number: u64,
        payment_date: u64,
        record_date: u64,
        amount_per_bond: u64,
        total_amount: u64,
        principal_at_record: u64
    ): CouponPayment {
        CouponPayment {
            coupon_number,
            payment_date,
            record_date,
            amount_per_bond,
            total_amount,
            principal_at_record,
            paid: false,
            actual_payment_date: option::none(),
            payment_tx: option::none(),
        }
    }

    // ========== VALIDATION ==========
    
    /// Require schedule is generated
    public fun require_schedule_generated(state: &InterestEngineState) {
        assert!(state.schedule.schedule_generated, EScheduleAlreadyGenerated);
    }

    /// Require coupon exists
    public fun require_coupon_exists(state: &InterestEngineState, coupon_number: u64) {
        assert!(coupon_exists(state, coupon_number), ECouponNotFound);
    }

    /// Require coupon not paid
    public fun require_coupon_unpaid(state: &InterestEngineState, coupon_number: u64) {
        require_coupon_exists(state, coupon_number);
        let coupon = get_coupon(state, coupon_number);
        assert!(!coupon.paid, ECouponAlreadyPaid);
    }
}
