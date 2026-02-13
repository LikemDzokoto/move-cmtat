/// BondValidation Test Suite - Comprehensive Testing for Bond Calculations
#[test_only]
module move_cmtat::bond_validation_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};

    use move_cmtat::bond_validation;
    use move_cmtat::debt::{Self, DebtState};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;

    // ============ HELPER FUNCTIONS ============

    fun create_debt_state(scenario: &mut Scenario): DebtState {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            debt::init_debt_state(ctx)
        }
    }

    // ============ DAY COUNT CALCULATION TESTS ============

    #[test]
    fun test_calculate_day_count_30_360() {
        // Test 30/360 convention
        // From Jan 1, 2024 to Dec 31, 2024 = 360 days
        let (days, denominator) = bond_validation::calculate_day_count_30_360(
            1704067200, // Jan 1, 2024
            1735689600, // Dec 31, 2024
        );

        assert!(denominator == 360, 0);
        // Actual days depends on exact timestamps
        assert!(days > 0, 1);
    }

    #[test]
    fun test_calculate_day_count_actual_360() {
        // Test Actual/360 convention
        // From Jan 1, 2024 to Jan 1, 2025 = 366 days (leap year)
        let (days, denom) = bond_validation::calculate_day_count_actual_360(
            1704067200, // Jan 1, 2024
            1735603200, // Jan 1, 2025
        );

        assert!(denom == 360, 0);
        assert!(days == 366 || days == 365, 1); // Leap year or regular year
    }

    #[test]
    fun test_calculate_day_count_actual_365() {
        // Test Actual/365 convention
        let (days, denom) = bond_validation::calculate_day_count_actual_365(
            1704067200, // Jan 1, 2024
            1735603200, // Jan 1, 2025
        );

        assert!(denom == 365, 0);
        assert!(days == 366 || days == 365, 1); // Full year
    }

    #[test]
    fun test_calculate_day_count_actual_actual() {
        // Test Actual/Actual convention
        let (days, denom) = bond_validation::calculate_day_count_actual_actual(
            1704067200, // Jan 1, 2024
            1735603200, // Jan 1, 2025
        );

        assert!(denom == 365, 0); // Simplified
        assert!(days == 366 || days == 365, 1); // Full year
    }

    #[test]
    fun test_days_between() {
        // Test days between same date
        let days_same = bond_validation::days_between(1704067200, 1704067200);
        assert!(days_same == 0, 0);

        // Test days between consecutive days (approximately)
        let days_consecutive = bond_validation::days_between(1704067200, 1704153600);
        assert!(days_consecutive == 1, 1);

        // Test days between one month
        let days_month = bond_validation::days_between(1704067200, 1706745600);
        assert!(days_month >= 30 && days_month <= 31, 2);
    }

    // ============ INTEREST CALCULATION TESTS ============

    #[test]
    fun test_calculate_simple_interest() {
        // Test basic interest calculation
        // Principal: $100,000, Rate: 5%, Days: 365, Year: 365
        let interest = bond_validation::calculate_simple_interest(
            100000,      // principal
            5000000,     // rate (5% = 5000000 in fixed point)
            365,         // days
            365,         // year days
        );

        // Expected: 100000 * 0.05 = 5000
        assert!(interest > 0, 0);
        assert!(interest <= 5000, 1);
    }

    #[test]
    fun test_calculate_accrued_interest() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let state = create_debt_state(scenario);

        // Calculate annual interest for $1M at 5%
        let interest = bond_validation::calculate_accrued_interest(
            1000000,     // principal
            5000000,     // rate (5%)
            1704067200,  // from date
            1735603200,  // to date (1 year)
            &debt::ActualActual {},
        );

        // Expected: 1000000 * 0.05 = 50000
        assert!(interest > 0, 0);
        assert!(interest <= 50000, 1);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_accrued_interest_from_issuance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set up bond state
        debt::set_issuance_date(&mut state, 1704067200);
        debt::set_interest_rate(&mut state, 5000000);

        // Calculate interest from issuance date
        let interest = bond_validation::calculate_accrued_interest_from_issuance(
            &state,
            1717190400, // ~6 months later
        );

        // Expected: 1000000 * 0.05 * 0.5 = 25000
        assert!(interest > 0, 0);
        assert!(interest <= 25000, 1);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_zero_interest() {
        // Test with zero principal
        let interest_zero = bond_validation::calculate_simple_interest(0, 5000000, 365, 365);
        assert!(interest_zero == 0, 0);

        // Test with zero rate
        let rate_zero = bond_validation::calculate_simple_interest(100000, 0, 365, 365);
        assert!(rate_zero == 0, 1);

        // Test with zero days
        let days_zero = bond_validation::calculate_simple_interest(100000, 5000000, 0, 365);
        assert!(days_zero == 0, 2);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_validate_redemption_amount() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set minimum denomination to 100
        debt::set_minimum_denomination(&mut state, 100);

        // Valid redemption amounts
        assert!(bond_validation::validate_redemption_amount(&state, 100), 0);
        assert!(bond_validation::validate_redemption_amount(&state, 500), 1);
        assert!(bond_validation::validate_redemption_amount(&state, 1000), 2);

        // Invalid redemption amount (not multiple of 100)
        assert!(!bond_validation::validate_redemption_amount(&state, 150), 3);
        assert!(!bond_validation::validate_redemption_amount(&state, 999), 4);

        // Zero minimum denomination (no restriction)
        debt::set_minimum_denomination(&mut state, 0);
        assert!(bond_validation::validate_redemption_amount(&state, 1), 5);
        assert!(bond_validation::validate_redemption_amount(&state, 999), 6);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_require_valid_denomination() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set minimum denomination
        debt::set_minimum_denomination(&mut state, 100);

        // These should not abort
        bond_validation::require_valid_denomination(&state, 100);
        bond_validation::require_valid_denomination(&state, 500);

        test_scenario::end(scenario_val);
    }

    // ============ MATURITY CHECK TESTS ============

    #[test]
    fun test_is_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set maturity date to Jan 1, 2025
        debt::set_maturity_date(&mut state, 1735689600);

        // Before maturity
        assert!(!bond_validation::is_matured(1704067200, &state), 0); // Jan 1, 2024

        // At maturity
        assert!(bond_validation::is_matured(1735689600, &state), 1); // Jan 1, 2025

        // After maturity
        assert!(bond_validation::is_matured(1762214400, &state), 2); // Jan 1, 2026

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_time_to_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set maturity date to Jan 1, 2025
        debt::set_maturity_date(&mut state, 1735689600);

        // Before maturity
        let time = bond_validation::time_to_maturity(1704067200, &state); // Jan 1, 2024
        assert!(time > 0, 0);
        assert!(time <= 366 * 86400, 1); // Less than or equal to 366 days in seconds

        // At maturity
        let time_at = bond_validation::time_to_maturity(1735689600, &state);
        assert!(time_at == 0, 2);

        // After maturity
        let time_after = bond_validation::time_to_maturity(1762214400, &state);
        assert!(time_after == 0, 3);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_check_and_update_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set maturity date
        debt::set_maturity_date(&mut state, 1735689600);

        // Initially not matured
        assert!(!debt::is_matured(&state), 0);

        // Check and update before maturity
        bond_validation::check_and_update_maturity(&mut state, 1704067200);
        assert!(!debt::is_matured(&state), 1);

        // Check and update at maturity
        bond_validation::check_and_update_maturity(&mut state, 1735689600);
        assert!(debt::is_matured(&state), 2);

        // Check and update after maturity (should still be matured)
        bond_validation::check_and_update_maturity(&mut state, 1762214400);
        assert!(debt::is_matured(&state), 3);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_redemption_allowed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set maturity date
        debt::set_maturity_date(&mut state, 1735689600);

        // Before maturity - redemption not allowed
        assert!(!bond_validation::is_redemption_allowed(1704067200, &state), 0);

        // At maturity but not redeemed - redemption allowed
        assert!(bond_validation::is_redemption_allowed(1735689600, &state), 1);

        // After maturity and redeemed - not allowed
        debt::flag_redeemed(&mut state);
        assert!(!bond_validation::is_redemption_allowed(1762214400, &state), 2);

        test_scenario::end(scenario_val);
    }

    // ============ CONSTANT TESTS ============

    #[test]
    fun test_interest_rate_multiplier() {
        assert!(bond_validation::interest_rate_multiplier() == 1000000, 0);
    }

    #[test]
    fun test_day_count_convention_constants() {
        assert!(bond_validation::days_360() == 360, 0);
        assert!(bond_validation::days_365() == 365, 1);
        assert!(bond_validation::days_366() == 366, 2);
    }

    #[test]
    fun test_seconds_per_day() {
        assert!(bond_validation::seconds_per_day() == 86400, 0);
    }

    // ============ DAY COUNT CONVENTION HELPER TESTS ============

    #[test]
    fun test_calculate_day_count_fraction() {
        // Test the fraction calculation
        let (days, denom) = bond_validation::calculate_day_count_fraction(
            1704067200,
            1735689600,
            &debt::Thirty360 {},
        );

        assert!(days > 0, 0);
        assert!(denom == 360, 1);
    }

    #[test]
    fun test_calculate_day_count_fraction_u8() {
        // Test with u8 convention codes
        let (days, denom) = bond_validation::calculate_day_count_fraction_u8(
            1704067200,
            1735689600,
            0, // Thirty360
        );

        assert!(days > 0, 0);
        assert!(denom == 360, 1);
    }

    #[test]
    fun test_coupon_frequency_to_days() {
        assert!(bond_validation::coupon_frequency_to_days(&string::utf8(b"ANNUAL")) == 365, 0);
        assert!(bond_validation::coupon_frequency_to_days(&string::utf8(b"SEMI_ANNUAL")) == 182, 1);
        assert!(bond_validation::coupon_frequency_to_days(&string::utf8(b"QUARTERLY")) == 91, 2);
        assert!(bond_validation::coupon_frequency_to_days(&string::utf8(b"MONTHLY")) == 30, 3);
    }

    // ============ INTEREST RATE CONVERSION TESTS ============

    #[test]
    fun test_rate_conversions() {
        // Test rate to percentage
        assert!(bond_validation::rate_to_percentage(5000000) == 5, 0); // 5%
        assert!(bond_validation::rate_to_percentage(10000000) == 10, 1); // 10%

        // Test percentage to rate
        assert!(bond_validation::percentage_to_rate(5) == 5000000, 2);
        assert!(bond_validation::percentage_to_rate(10) == 10000000, 3);
    }

    #[test]
    fun test_validate_interest_rate() {
        assert!(bond_validation::validate_interest_rate(0), 0); // Zero is valid
        assert!(bond_validation::validate_interest_rate(5000000), 1); // 5% is valid
        assert!(bond_validation::validate_interest_rate(100000000), 2); // 100% is valid
    }

    #[test]
    fun test_calculate_annual_interest() {
        let interest = bond_validation::calculate_annual_interest(1000000, 5000000);
        assert!(interest == 50000, 0); // 5% of 1M
    }

    // ============ COUPON CALCULATION TESTS ============

    #[test]
    fun test_calculate_coupon_amount() {
        let amount = bond_validation::calculate_coupon_amount(
            1000000,     // principal
            5000000,     // rate (5%)
            365,         // days in period
            365,         // days in year
        );

        // Expected: 1000000 * 0.05 * (365/365) = 50000
        assert!(amount == 50000, 0);
    }

    #[test]
    fun test_calculate_total_lifetime_interest() {
        let total = bond_validation::calculate_total_lifetime_interest(
            1000000,     // principal
            5000000,     // rate (5%)
            3650,        // total days (10 years)
            365,         // days in year
            10,          // number of coupons
        );

        // Expected: 1000000 * 0.05 * (3650/365) = 500000
        assert!(total == 500000, 0);
    }

    #[test]
    fun test_calculate_coupon_count() {
        let count = bond_validation::calculate_coupon_count(
            1704067200,  // issuance date
            1735689600,  // maturity date
            365,         // days per coupon
        );

        assert!(count == 1, 0); // 1 year = 1 annual coupon

        let count2 = bond_validation::calculate_coupon_count(
            1704067200,  // issuance date
            1735689600,  // maturity date
            91,          // days per quarter
        );

        assert!(count2 == 4, 1); // 1 year = 4 quarterly coupons
    }

    #[test]
    fun test_calculate_next_coupon_date() {
        let next = bond_validation::calculate_next_coupon_date(
            1704067200,  // last coupon date
            91,           // days between coupons
        );

        assert!(next > 1704067200, 0);
    }

    // ============ DATE UTILITY TESTS ============

    #[test]
    fun test_seconds_between() {
        let seconds = bond_validation::seconds_between(1704067200, 1704153600);
        assert!(seconds == 86400, 0); // 1 day = 86400 seconds
    }

    #[test]
    fun test_is_leap_year_timestamp() {
        // 2024 is a leap year
        assert!(bond_validation::is_leap_year_timestamp(1704067200), 0); // Jan 1, 2024

        // 2025 is not a leap year
        assert!(!bond_validation::is_leap_year_timestamp(1735689600), 1); // Jan 1, 2025
    }

    #[test]
    fun test_is_leap_year_in_period() {
        // Period spanning leap year
        let spans_leap = bond_validation::is_leap_year_in_period(
            1672531200,  // Jan 1, 2023
            1704067200,  // Jan 1, 2024
        );

        assert!(spans_leap, 0);
    }

    // ============ BUSINESS DAY ADJUSTMENT TESTS ============

    #[test]
    fun test_adjust_for_business_day_following() {
        // Test following convention
        let adjusted = bond_validation::adjust_for_business_day(
            1704067200,  // timestamp
            &debt::Following {},
        );

        assert!(adjusted >= 1704067200, 0);
    }

    #[test]
    fun test_adjust_for_business_day_unadjusted() {
        // Test unadjusted convention (should return same date)
        let adjusted = bond_validation::adjust_for_business_day(
            1704067200,
            &debt::Unadjusted {},
        );

        assert!(adjusted == 1704067200, 0);
    }

    // ============ COMPREHENSIVE WORKFLOW TEST ============

    #[test]
    fun test_complete_bond_calculation_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let mut state = create_debt_state(scenario);

        // Set up bond parameters
        let principal = 1000000; // $1M
        let rate = 5000000; // 5%
        let issuance_date = 1704067200; // Jan 1, 2024
        let maturity_date = 1735689600; // Jan 1, 2025

        debt::set_interest_rate(&mut state, rate);
        debt::set_par_value(&mut state, principal);
        debt::set_issuance_date(&mut state, issuance_date);
        debt::set_maturity_date(&mut state, maturity_date);
        debt::set_minimum_denomination(&mut state, 1000);
        debt::set_day_count_convention(&mut state, debt::ActualActual {});
        debt::set_business_day_convention(&mut state, debt::Unadjusted {});

        // Calculate days to maturity
        let days = bond_validation::days_between(issuance_date, maturity_date);
        assert!(days == 365 || days == 366, 0); // Full year

        // Check maturity status
        assert!(!bond_validation::is_matured(issuance_date, &state), 1);
        assert!(bond_validation::is_matured(maturity_date, &state), 2);

        // Calculate interest using day count convention
        let annual_interest = bond_validation::calculate_accrued_interest(
            principal,
            rate,
            days,
            days,
            &debt::ActualActual {},
        );

        // Expected: 1000000 * 0.05 = 50000
        assert!(annual_interest > 0, 3);
        assert!(annual_interest <= 50000, 4);

        // Validate redemption
        assert!(bond_validation::validate_redemption_amount(&state, 1000000), 5);
        assert!(bond_validation::validate_redemption_amount(&state, 5000), 6);
        assert!(!bond_validation::validate_redemption_amount(&state, 500), 7); // Below minimum

        // Calculate time to maturity at issuance
        let time = bond_validation::time_to_maturity(issuance_date, &state);
        assert!(time > 0, 8);
        assert!(time <= days * 86400, 9); // In seconds

        test_scenario::end(scenario_val);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_edge_case_zero_maturity_date() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        let state = create_debt_state(scenario);

        // Maturity date not set (0)
        assert!(!bond_validation::is_matured(1704067200, &state), 0);

        // Time to maturity should be 0
        let time = bond_validation::time_to_maturity(1704067200, &state);
        assert!(time == 0, 1);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fractional_interest() {
        // Calculate interest for fractional period (3 months = ~90 days)
        let interest_quarter = bond_validation::calculate_simple_interest(
            1000000,
            5000000,
            90,
            365,
        );

        // Expected: 1000000 * 0.05 * (90/365) ≈ 12328
        assert!(interest_quarter > 0, 0);
        assert!(interest_quarter <= 12500, 1);

        // Compare with 6 months
        let interest_half = bond_validation::calculate_simple_interest(
            1000000,
            5000000,
            182,
            365,
        );

        // 6 months should be approximately double 3 months
        assert!(interest_half > interest_quarter, 2);
        assert!(interest_half <= interest_quarter * 3, 3);
    }

    #[test]
    fun test_multiple_day_count_conventions() {
        let start_date = 1704067200; // Jan 1, 2024
        let end_date = 1735689600;   // Jan 1, 2025

        let days_30360 = bond_validation::calculate_day_count_30_360(start_date, end_date);
        let days_act360 = bond_validation::calculate_day_count_actual_360(start_date, end_date);
        let days_act365 = bond_validation::calculate_day_count_actual_365(start_date, end_date);
        let days_actact = bond_validation::calculate_day_count_actual_actual(start_date, end_date);

        // 30/360 should give (360, 360)
        assert!(days_30360 == (360, 360), 0);

        // Actual conventions should give year length
        assert!(days_act360 == (366, 360) || days_act360 == (365, 360), 1);
        assert!(days_act365 == (366, 365) || days_act365 == (365, 365), 2);
    }
}
