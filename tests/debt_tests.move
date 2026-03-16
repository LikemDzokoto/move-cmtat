/// Debt Component Test Suite - Tests for debt data structures and getters

#[test_only]
#[allow(unused_use, unused_function, unused_const)]
module move_cmtat::debt_tests {
    use std::string;
    use iota::test_scenario::{Self};

    use move_cmtat::debt::{Self, DebtIdentifier, DebtInstrument, BondTerms, CreditEvents};

    const ADMIN: address = @0xAD;

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_debt_identifier() {
        let identifier = debt::init_debt_identifier();

        assert!(debt::identifier_get_issuer_name(&identifier) == string::utf8(b""), 0);
        assert!(debt::identifier_get_isin(&identifier) == string::utf8(b""), 1);
    }

    #[test]
    fun test_init_debt_instrument() {
        let instrument = debt::init_debt_instrument();

        assert!(debt::instrument_get_interest_rate(&instrument) == 0, 0);
        assert!(debt::instrument_get_par_value(&instrument) == 0, 1);
        assert!(debt::instrument_get_maturity_date(&instrument) == 0, 2);
    }

    #[test]
    fun test_init_credit_events() {
        let events = debt::init_credit_events();

        assert!(!debt::credit_events_is_default(&events), 0);
        assert!(!debt::credit_events_is_redeemed(&events), 1);
        assert!(!debt::credit_events_is_matured(&events), 2);
        assert!(debt::credit_events_get_rating(&events) == string::utf8(b""), 3);
    }

    // ============ CREDIT EVENTS STRUCT TESTS ============

    #[test]
    fun test_credit_events_struct_operations() {
        let mut events = debt::init_credit_events();

        debt::credit_events_flag_default(&mut events);
        assert!(debt::credit_events_is_default(&events), 0);

        debt::credit_events_clear_default(&mut events);
        assert!(!debt::credit_events_is_default(&events), 1);

        debt::credit_events_flag_redeemed(&mut events);
        assert!(debt::credit_events_is_redeemed(&events), 2);

        debt::credit_events_flag_matured(&mut events);
        assert!(debt::credit_events_is_matured(&events), 3);

        debt::credit_events_set_rating(&mut events, string::utf8(b"AA+"));
        assert!(debt::credit_events_get_rating(&events) == string::utf8(b"AA+"), 4);

        debt::credit_events_record_principal(&mut events, 500_000);
        assert!(debt::credit_events_get_principal_distributed(&events) == 500_000, 5);
    }

    // ============ DAY COUNT CONVENTION TESTS ============

    #[test]
    fun test_day_count_conversions() {
        let d30_360 = debt::u8_to_day_count(0);
        let actual360 = debt::u8_to_day_count(1);
        let actual365 = debt::u8_to_day_count(2);
        let actualactual = debt::u8_to_day_count(3);

        assert!(debt::day_count_to_u8(&d30_360) == 0, 0);
        assert!(debt::day_count_to_u8(&actual360) == 1, 1);
        assert!(debt::day_count_to_u8(&actual365) == 2, 2);
        assert!(debt::day_count_to_u8(&actualactual) == 3, 3);
    }

    #[test]
    fun test_business_day_conversions() {
        let following = debt::u8_to_business_day(0);
        let mod_following = debt::u8_to_business_day(1);
        let preceding = debt::u8_to_business_day(2);
        let unadjusted = debt::u8_to_business_day(3);

        assert!(debt::business_day_to_u8(&following) == 0, 0);
        assert!(debt::business_day_to_u8(&mod_following) == 1, 1);
        assert!(debt::business_day_to_u8(&preceding) == 2, 2);
        assert!(debt::business_day_to_u8(&unadjusted) == 3, 3);
    }

    #[test]
    fun test_day_count_constants() {
        assert!(debt::day_count_thirty360() == 0, 0);
        assert!(debt::day_count_actual360() == 1, 1);
        assert!(debt::day_count_actual365() == 2, 2);
        assert!(debt::day_count_actualactual() == 3, 3);
    }

    #[test]
    fun test_business_day_constants() {
        assert!(debt::bdc_following() == 0, 0);
        assert!(debt::bdc_modified_following() == 1, 1);
        assert!(debt::bdc_preceding() == 2, 2);
        assert!(debt::bdc_unadjusted() == 3, 3);
    }

    // ============ INSTRUMENT GETTER TESTS ============

    #[test]
    fun test_instrument_setters() {
        let  instrument = debt::init_debt_instrument();

        // These test the struct field setters
        assert!(debt::instrument_get_interest_rate(&instrument) == 0, 0);
    }

    #[test]
    fun test_identifier_setters() {
        let  identifier = debt::init_debt_identifier();

        // These test the struct field operations
        assert!(debt::identifier_get_issuer_name(&identifier) == string::utf8(b""), 0);
        assert!(debt::identifier_get_isin(&identifier) == string::utf8(b""), 1);
    }
}
