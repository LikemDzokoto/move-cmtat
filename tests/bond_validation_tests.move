/// BondValidation Test Suite - Tests for bond calculations and validations
#[test_only]
#[allow(unused_use, unused_function, unused_const)]
module move_cmtat::bond_validation_tests {
    use iota::test_scenario::{Self, Scenario};
    use std::string;

    use move_cmtat::bond_validation;
    use move_cmtat::debt;

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;

    // ============ DAY COUNT CALCULATION TESTS ============

    #[test]
    fun test_calculate_day_count_30_360() {
        let (days, denominator) = bond_validation::calculate_day_count_30_360(
            1704067200,
            1735689600,
        );

        assert!(denominator == 360, 0);
        assert!(days > 0, 1);
    }

    #[test]
    fun test_calculate_day_count_actual_360() {
        let (_days, denom) = bond_validation::calculate_day_count_actual_360(
            1704067200,
            1735603200,
        );

        assert!(denom == 360, 0);
    }

    #[test]
    fun test_calculate_day_count_actual_365() {
        let (_days, denom) = bond_validation::calculate_day_count_actual_365(
            1704067200,
            1735603200,
        );

        assert!(denom == 365, 0);
    }

    #[test]
    fun test_calculate_day_count_actual_actual() {
        let (_days, denom) = bond_validation::calculate_day_count_actual_actual(
            1704067200,
            1735603200,
        );

        assert!(denom == 365 || denom == 366, 0);
    }

    #[test]
    fun test_calculate_day_count_fraction() {
        let convention = debt::u8_to_day_count(0); // Thirty360

        let (_days, denom) = bond_validation::calculate_day_count_fraction(
            1704067200,
            1735603200,
            &convention,
        );

        assert!(denom == 360, 0);
    }

    #[test]
    fun test_calculate_day_count_fraction_u8() {
        let (_days1, denom1) = bond_validation::calculate_day_count_fraction_u8(
            1704067200,
            1735603200,
            0, // Thirty360
        );
        assert!(denom1 == 360, 0);

        let (_, denom2) = bond_validation::calculate_day_count_fraction_u8(
            1704067200,
            1735603200,
            1, // Actual360
        );
        assert!(denom2 == 360, 1);

        let (_, denom3) = bond_validation::calculate_day_count_fraction_u8(
            1704067200,
            1735603200,
            2, // Actual365
        );
        assert!(denom3 == 365, 2);
    }

    // ============ INTEREST CALCULATION TESTS ============

    #[test]
    fun test_calculate_simple_interest() {
        let interest = bond_validation::calculate_simple_interest(
            100000,
            5000000,
            365,
            365,
        );

        assert!(interest == 500000, 0);
    }

    #[test]
    fun test_calculate_simple_interest_zero() {
        let interest1 = bond_validation::calculate_simple_interest(0, 5000000, 365, 365);
        assert!(interest1 == 0, 0);

        let interest2 = bond_validation::calculate_simple_interest(100000, 0, 365, 365);
        assert!(interest2 == 0, 1);

        let interest3 = bond_validation::calculate_simple_interest(100000, 5000000, 0, 365);
        assert!(interest3 == 0, 2);
    }

    #[test]
    fun test_calculate_simple_interest_various_rates() {
        let interest_1_percent = bond_validation::calculate_simple_interest(
            100000,
            1000000,
            365,
            365,
        );
        assert!(interest_1_percent == 100000, 0);

        let interest_10_percent = bond_validation::calculate_simple_interest(
            100000,
            10000000,
            365,
            365,
        );
        assert!(interest_10_percent == 1000000, 1);
    }

    #[test]
    fun test_calculate_accrued_interest() {
        let convention = debt::u8_to_day_count(2); // Actual365

        let accrued = bond_validation::calculate_accrued_interest(
            100000,
            5000000,
            1704067200,
            1735603200,
            &convention,
        );

        assert!(accrued > 0, 0);
    }

    #[test]
    fun test_calculate_accrued_interest_short_period() {
        let convention = debt::u8_to_day_count(0); // Thirty360

        let accrued = bond_validation::calculate_accrued_interest(
            100000,
            5000000,
            1704067200,
            1704672000,
            &convention,
        );

        assert!(accrued > 0, 0);
    }

    #[test]
    fun test_calculate_coupon_amount() {
        let convention = debt::u8_to_day_count(2); // Actual365

        let coupon = bond_validation::calculate_coupon_amount(
            100000,
            5000000,
            &convention,
        );

        assert!(coupon > 0, 0);
    }

    #[test]
    fun test_calculate_total_lifetime_interest() {
        let convention = debt::u8_to_day_count(2); // Actual365

        let total = bond_validation::calculate_total_lifetime_interest(
            100000,
            5000000,
            1704067200,
            1775603200,
            &convention,
        );

        assert!(total > 0, 0);
    }

    // ============ DATE UTILITY TESTS ============

    #[test]
    fun test_days_between() {
        let days_same = bond_validation::days_between(1704067200, 1704067200);
        assert!(days_same == 0, 0);

        let days_consecutive = bond_validation::days_between(1704067200, 1704153600);
        assert!(days_consecutive == 1, 1);

        let days_month = bond_validation::days_between(1704067200, 1706745600);
        assert!(days_month >= 30 && days_month <= 31, 2);
    }

    #[test]
    fun test_seconds_between() {
        let seconds_same = bond_validation::seconds_between(1704067200, 1704067200);
        assert!(seconds_same == 0, 0);

        let seconds_day = bond_validation::seconds_between(1704067200, 1704153600);
        assert!(seconds_day == 86400, 1);
    }

    #[test]
    fun test_is_leap_year_timestamp() {
        // is_leap_year_in_period covers leap year checks
        let result = bond_validation::is_leap_year_in_period(1704067200, 1735689600);
        assert!(result == true, 0);

        let result2 = bond_validation::is_leap_year_in_period(1672531200, 1704067199);
        assert!(result2 == false, 1);
    }

    #[test]
    fun test_is_leap_year() {
        let result = bond_validation::is_leap_year_in_period(1704067200, 1735689600);
        assert!(result == true, 0);

        let result2 = bond_validation::is_leap_year_in_period(1672531200, 1704067199);
        assert!(result2 == false, 1);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_validate_interest_rate() {
        let valid = bond_validation::validate_interest_rate(5000000);
        assert!(valid == true, 0);

        let valid2 = bond_validation::validate_interest_rate(10000000);
        assert!(valid2 == true, 1);

        // 100% = 100000000, still valid
        let valid3 = bond_validation::validate_interest_rate(100000000);
        assert!(valid3 == true, 2);

        // 1500% > 1000% = invalid
        let valid4 = bond_validation::validate_interest_rate(1500000000);
        assert!(valid4 == false, 3);
    }

    #[test]
    fun test_interest_rate_multiplier() {
        let multiplier = bond_validation::interest_rate_multiplier();
        assert!(multiplier == 1000000, 0);
    }

    #[test]
    fun test_rate_to_percentage() {
        let percentage = bond_validation::rate_to_percentage(5000000);
        assert!(percentage == 500, 0);
    }

    #[test]
    fun test_percentage_to_rate() {
        let rate = bond_validation::percentage_to_rate(5);
        assert!(rate == 50000, 0);
    }

    #[test]
    fun test_calculate_annual_interest() {
        let annual = bond_validation::calculate_annual_interest(100000, 5000000);
        assert!(annual == 500000, 0);
    }

    // ============ COUPON TESTS ============

    #[test]
    fun test_coupon_frequency_to_days() {
        let annual_days = bond_validation::coupon_frequency_to_days(&string::utf8(b"ANNUAL"));
        assert!(annual_days == 365, 0);
    }

    #[test]
    fun test_calculate_coupon_count() {
        let count = bond_validation::calculate_coupon_count(
            1704067200,
            1735603200,
            &string::utf8(b"ANNUAL"),
        );
        assert!(count >= 1, 0);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_zero_principal_accrued_interest() {
        let convention = debt::u8_to_day_count(2); // Actual365

        let accrued = bond_validation::calculate_accrued_interest(
            0,
            5000000,
            1704067200,
            1735603200,
            &convention,
        );

        assert!(accrued == 0, 0);
    }

    #[test]
    fun test_same_day_no_accrued_interest() {
        let convention = debt::u8_to_day_count(2); // Actual365

        let accrued = bond_validation::calculate_accrued_interest(
            100000,
            5000000,
            1704067200,
            1704067200,
            &convention,
        );

        assert!(accrued == 0, 0);
    }

    #[test]
    fun test_calculate_day_count_same_date() {
        let (days, denom) = bond_validation::calculate_day_count_30_360(
            1704067200,
            1704067200,
        );

        assert!(days == 0, 0);
        assert!(denom == 360, 1);
    }
}
