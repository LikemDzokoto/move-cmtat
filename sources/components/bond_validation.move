/// Bond Validation Component - Interest Calculations & Bond-Specific Logic
/// Comprehensive validation and calculation functions for debt securities
/// Implements day count conventions, business day rules, and interest math
#[allow(unused_const)]
module move_cmtat::bond_validation {
    use std::string::String;
    use move_cmtat::debt::{Self, DebtState, DayCountConvention, BusinessDayConvention};


    
    /// Fixed-point multiplier for interest rates (6 decimals)
    const INTEREST_RATE_MULTIPLIER: u64 = 1_000_000;
    

    const DAYS_360: u64 = 360;
    const DAYS_365: u64 = 365;
    const DAYS_366: u64 = 366;
    
    /// Seconds in a day
    const SECONDS_PER_DAY: u64 = 86400;
    
    /// Seconds in common year
    const SECONDS_PER_YEAR_365: u64 = 31536000;
    
    /// Seconds in leap year
    const SECONDS_PER_YEAR_366: u64 = 31622400;


    
    const EInvalidDayCountConvention: u64 = 500;
    const EInvalidBusinessDayConvention: u64 = 501;
    const EInvalidDateRange: u64 = 502;
    const EInvalidInterestCalculation: u64 = 503;
    const EBondMatured: u64 = 504;
    const EMinimumDenominationViolation: u64 = 505;
    const EInvalidTimestamp: u64 = 506;
    const ECalculationOverflow: u64 = 507;


    
    /// Calculate day count fraction using 30/360 convention
    /// Formula: (360*(y2-y1) + 30*(m2-m1) + (d2-d1)) / 360

    public fun calculate_day_count_30_360(start_date: u64, end_date: u64): (u64, u64) {

        assert!(end_date >= start_date, EInvalidDateRange);
        
        // Calculate days between timestamps
        let days = days_between(start_date, end_date);
        
        // 30/360 uses 360-day year
        (days, DAYS_360)
    }

    /// Calculate day count fraction using Actual/360
    public fun calculate_day_count_actual_360(start_date: u64, end_date: u64): (u64, u64) {
        assert!(end_date >= start_date, EInvalidDateRange);
        
        let days = days_between(start_date, end_date);
        (days, DAYS_360)
    }

    /// Calculate day count fraction using Actual/365
    public fun calculate_day_count_actual_365(start_date: u64, end_date: u64): (u64, u64) {
        assert!(end_date >= start_date, EInvalidDateRange);
        
        let days = days_between(start_date, end_date);
        (days, DAYS_365)
    }

    /// Calculate day count fraction using Actual/Actual
    /// Accounts for leap years in the period
    public fun calculate_day_count_actual_actual(start_date: u64, end_date: u64): (u64, u64) {
        assert!(end_date >= start_date, EInvalidDateRange);
        
        let days = days_between(start_date, end_date);
        
        // Determine actual days in year for the period
        // Simplified: use 365 for now, could be enhanced for leap year detection
        let year_days = if (is_leap_year_in_period(start_date, end_date)) {
            DAYS_366
        } else {
            DAYS_365
        };
        
        (days, year_days)
    }

    /// Generic day count calculation based on convention (using u8 constants)
    public fun calculate_day_count_fraction(
        start_date: u64,
        end_date: u64,
        convention: &DayCountConvention
    ): (u64, u64) {
        let convention_u8 = debt::day_count_to_u8(convention);
        if (convention_u8 == debt::day_count_thirty360()) {
            calculate_day_count_30_360(start_date, end_date)
        } else if (convention_u8 == debt::day_count_actual360()) {
            calculate_day_count_actual_360(start_date, end_date)
        } else if (convention_u8 == debt::day_count_actual365()) {
            calculate_day_count_actual_365(start_date, end_date)
        } else {
            calculate_day_count_actual_actual(start_date, end_date)
        }
    }

    /// Alternative using u8 directly
    public fun calculate_day_count_fraction_u8(
        start_date: u64,
        end_date: u64,
        convention_u8: u8
    ): (u64, u64) {
        if (convention_u8 == debt::day_count_thirty360()) {
            calculate_day_count_30_360(start_date, end_date)
        } else if (convention_u8 == debt::day_count_actual360()) {
            calculate_day_count_actual_360(start_date, end_date)
        } else if (convention_u8 == debt::day_count_actual365()) {
            calculate_day_count_actual_365(start_date, end_date)
        } else {
            calculate_day_count_actual_actual(start_date, end_date)
        }
    }


    

    /// Formula: principal * rate * (days_numerator / days_denominator)
    /// Rate is fixed-point (e.g., 5250000 for 5.25%)
    /// Returns interest amount in base units
    public fun calculate_simple_interest(
        principal: u64,
        rate_fixed_point: u64,
        days_numerator: u64,
        days_denominator: u64
    ): u64 {

        assert!(days_denominator > 0, EInvalidInterestCalculation);
        
        if (principal == 0 || rate_fixed_point == 0 || days_numerator == 0) {
            return 0
        };
        
        // Calculate: principal * rate * days / (multiplier * total_days)
        // Use u128 to prevent overflow
        let principal_times_rate = (principal as u128) * (rate_fixed_point as u128);
        let interest = principal_times_rate * (days_numerator as u128);
        let denominator = (INTEREST_RATE_MULTIPLIER as u128) * (days_denominator as u128);
        

        assert!(denominator > 0, ECalculationOverflow);
        
        ((interest / denominator) as u64)
    }

    /// Calculate accrued interest from start date to end date
    /// Uses the bond's day count convention
    public fun calculate_accrued_interest(
        principal: u64,
        rate_fixed_point: u64,
        start_date: u64,
        end_date: u64,
        convention: &DayCountConvention
    ): u64 {
        let (days_num, days_den) = calculate_day_count_fraction(start_date, end_date, convention);
        calculate_simple_interest(principal, rate_fixed_point, days_num, days_den)
    }

    /// Calculate accrued interest from bond issuance to current time
    public fun calculate_accrued_interest_from_issuance(
        state: &DebtState,
        current_time: u64,
        principal: u64
    ): u64 {
        let issuance_date = debt::get_issuance_date(state);
        let rate = debt::get_interest_rate(state);
        let convention = debt::get_day_count_convention(state);
        
        // If before issuance, no interest
        if (current_time <= issuance_date || issuance_date == 0) {
            return 0
        };
        
        calculate_accrued_interest(principal, rate, issuance_date, current_time, &convention)
    }

    /// Calculate next coupon amount for given principal
    public fun calculate_coupon_amount(
        principal: u64,
        rate_fixed_point: u64,
        convention: &DayCountConvention
    ): u64 {
        // Calculate interest for one coupon period
        // Period length depends on convention
        let convention_u8 = debt::day_count_to_u8(convention);
        let (period_days, year_days) = if (convention_u8 == debt::day_count_thirty360()) {
            (30u64, DAYS_360)
        } else {
            (year_days_to_period(DAYS_365, &get_coupon_frequency_from_rate(rate_fixed_point)), DAYS_365)
        };
        
        calculate_simple_interest(principal, rate_fixed_point, period_days, year_days)
    }

    /// Calculate total interest over bond lifetime
    public fun calculate_total_lifetime_interest(
        principal: u64,
        rate_fixed_point: u64,
        issuance_date: u64,
        maturity_date: u64,
        convention: &DayCountConvention
    ): u64 {
        if (maturity_date <= issuance_date) {
            return 0
        };
        
        calculate_accrued_interest(principal, rate_fixed_point, issuance_date, maturity_date, convention)
    }


    
    /// Calculate days between two timestamps
    public fun days_between(start_timestamp: u64, end_timestamp: u64): u64 {
        assert!(end_timestamp >= start_timestamp, EInvalidDateRange);
        (end_timestamp - start_timestamp) / SECONDS_PER_DAY
    }

    /// Calculate seconds between timestamps
    public fun seconds_between(start_timestamp: u64, end_timestamp: u64): u64 {
        assert!(end_timestamp >= start_timestamp, EInvalidDateRange);
        end_timestamp - start_timestamp
    }

    /// Check if timestamp falls in a leap year
    /// Simplified: assumes timestamp is Unix epoch seconds
    public fun is_leap_year_timestamp(timestamp: u64): bool {
        let year = timestamp_to_year(timestamp);
        is_leap_year(year)
    }

    /// Check if any leap year exists in date range
    public fun is_leap_year_in_period(start_timestamp: u64, end_timestamp: u64): bool {
        let start_year = timestamp_to_year(start_timestamp);
        let end_year = timestamp_to_year(end_timestamp);
        
        let mut year = start_year;
        while (year <= end_year) {
            if (is_leap_year(year)) {
                return true
            };
            year = year + 1;
        };
        
        false
    }

    /// Check if year is a leap year
    fun is_leap_year(year: u64): bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }

    /// Convert timestamp to year (approximate)
    /// Note: This is simplified and doesn't account for exact leap year calculations
    fun timestamp_to_year(timestamp: u64): u64 {
        // Unix epoch starts at 1970
        // Average seconds per year accounting for leap years
        let avg_seconds_per_year = 31557600;
        1970 + (timestamp / avg_seconds_per_year)
    }


    
    /// Adjust date for business day convention
    /// Note: Full implementation would need external oracle for business days
    /// This is a simplified version
    public fun adjust_for_business_day(
        date: u64,
        convention: &BusinessDayConvention
    ): u64 {
        let convention_u8 = debt::business_day_to_u8(convention);
        if (convention_u8 == debt::bdc_unadjusted()) {
            date
        } else if (convention_u8 == debt::bdc_following()) {
            adjust_following(date)
        } else if (convention_u8 == debt::bdc_modified_following()) {
            adjust_modified_following(date)
        } else {
            adjust_preceding(date)
        }
    }

    /// Adjust to next business day (simplified)
    fun adjust_following(date: u64): u64 {
        // Simplified: add days to avoid weekends
        // In production, this would check actual business calendar
        let day_of_week = day_of_week(date);
        
        if (day_of_week == 0) {
            date + SECONDS_PER_DAY
        } else if (day_of_week == 6) {
            date + (2 * SECONDS_PER_DAY)
        } else {
            date
        }
    }

    /// Adjust to next business day, but not next month (simplified)
    fun adjust_modified_following(date: u64): u64 {
        let adjusted = adjust_following(date);
        
        // Check if we moved to next month
        if (month_of_year(date) != month_of_year(adjusted)) {
            // Move to preceding business day instead
            adjust_preceding(date)
        } else {
            adjusted
        }
    }

    /// Adjust to previous business day (simplified)
    fun adjust_preceding(date: u64): u64 {
        let day_of_week = day_of_week(date);
        
        if (day_of_week == 0) {
            date - (2 * SECONDS_PER_DAY)
        } else if (day_of_week == 6) {
            date - SECONDS_PER_DAY
        } else {
            date
        }
    }

    /// Calculate day of week (0 = Sunday, 6 = Saturday)
    /// Uses Zeller's congruence algorithm
    fun day_of_week(timestamp: u64): u64 {

        // Days since Unix epoch
        let days = timestamp / SECONDS_PER_DAY;
        // Jan 1, 1970 was a Thursday (4)
        (4 + days) % 7
    }

    /// Get month of year (1-12)
    fun month_of_year(timestamp: u64): u64 {

        // This is not precise but sufficient for basic Modified Following
        let days = timestamp / SECONDS_PER_DAY;
        let year_days = days % 365;
        
        if (year_days < 31) { return 1 }
        else if (year_days < 59) { return 2 }
        else if (year_days < 90) { return 3 }
        else if (year_days < 120) { return 4 }
        else if (year_days < 151) { return 5 }
        else if (year_days < 181) { return 6 }
        else if (year_days < 212) { return 7 }
        else if (year_days < 243) { return 8 }
        else if (year_days < 273) { return 9 }
        else if (year_days < 304) { return 10 }
        else if (year_days < 334) { return 11 }
        else { return 12 }
    }


    
    /// Check if bond has reached maturity
    public fun is_matured(current_time: u64, state: &DebtState): bool {
        debt::is_matured_at_time(current_time, state)
    }

    /// Validate minimum denomination for transfers
    public fun validate_minimum_denomination(state: &DebtState, amount: u64): bool {
        debt::validate_minimum_denomination(state, amount)
    }

    /// Require valid minimum denomination
    public fun require_valid_denomination(state: &DebtState, amount: u64) {
        debt::require_valid_minimum_denomination(state, amount);
    }

    /// Check if redemption is allowed (matured but not fully redeemed)
    public fun is_redemption_allowed(current_time: u64, state: &DebtState): bool {
        debt::is_redemption_allowed(current_time, state)
    }

    /// Check if bond is fully redeemed
    public fun is_fully_redeemed(state: &DebtState): bool {
        debt::is_fully_redeemed(state)
    }

    /// Validate redemption amount against remaining principal
    public fun validate_redemption_amount(state: &DebtState, amount: u64): bool {
        debt::validate_redemption_amount(state, amount)
    }

    /// Check maturity and update state if needed
    public fun check_and_update_maturity(state: &mut DebtState, current_time: u64) {
        debt::check_and_update_maturity(state, current_time);
    }

    /// Calculate time to maturity (returns 0 if already matured)
    public fun time_to_maturity(current_time: u64, state: &DebtState): u64 {
        debt::time_to_maturity(current_time, state)
    }

    /// Validate bond is not in default
    public fun require_not_in_default(state: &DebtState) {
        debt::require_not_in_default(state);
    }

    /// Validate bond is not fully redeemed
    public fun require_not_redeemed(state: &DebtState) {
        debt::require_not_redeemed(state);
    }


    
    /// Get period length in days from coupon frequency string
    public fun coupon_frequency_to_days(frequency: &String): u64 {
        let freq_copy = *frequency;
        let freq_str = std::string::to_ascii(freq_copy);
        
        if (freq_str == std::ascii::string(b"ANNUAL")) {
            365
        } else if (freq_str == std::ascii::string(b"SEMI_ANNUAL")) {
            182
        } else if (freq_str == std::ascii::string(b"QUARTERLY")) {
            91
        } else if (freq_str == std::ascii::string(b"MONTHLY")) {
            30
        } else {
            365
        }
    }

    /// Get period length from rate (infer from typical conventions)
    fun get_coupon_frequency_from_rate(_rate: u64): u64 {
        // Default to annual if unknown
        365
    }

    /// Calculate next coupon date from current date and frequency
    public fun calculate_next_coupon_date(
        current_date: u64,
        frequency: &String
    ): u64 {
        let period_days = coupon_frequency_to_days(frequency);
        current_date + (period_days * SECONDS_PER_DAY)
    }

    /// Calculate number of coupons between dates
    public fun calculate_coupon_count(
        start_date: u64,
        end_date: u64,
        frequency: &String
    ): u64 {
        let total_days = days_between(start_date, end_date);
        let period_days = coupon_frequency_to_days(frequency);
        
        if (period_days == 0) {
            return 0
        };
        
        total_days / period_days
    }


    
    /// Convert year days to period days based on coupon frequency
    fun year_days_to_period(year_days: u64, _frequency: &u64): u64 {

        year_days
    }

    /// Get fixed-point multiplier
    public fun interest_rate_multiplier(): u64 {
        INTEREST_RATE_MULTIPLIER
    }

    /// Convert rate to percentage for display
    public fun rate_to_percentage(rate_fixed_point: u64): u64 {
        rate_fixed_point / (INTEREST_RATE_MULTIPLIER / 100)
    }

    /// Convert percentage to fixed-point rate
    public fun percentage_to_rate(percentage: u64): u64 {
        percentage * (INTEREST_RATE_MULTIPLIER / 100)
    }

    /// Calculate annual interest for given principal and rate
    public fun calculate_annual_interest(principal: u64, rate_fixed_point: u64): u64 {
        calculate_simple_interest(principal, rate_fixed_point, DAYS_365, DAYS_365)
    }

    /// Validate interest rate is in reasonable range
    public fun validate_interest_rate(rate_fixed_point: u64): bool {
        // Validate rate is between 0% and 1000% (0 to 1,000,000,000 fixed-point)
        rate_fixed_point <= (1000 * INTEREST_RATE_MULTIPLIER)
    }

    /// Require valid interest rate
    public fun require_valid_interest_rate(rate_fixed_point: u64) {
        assert!(validate_interest_rate(rate_fixed_point), EInvalidInterestCalculation);
    }
}

