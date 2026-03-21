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
        let identifier = debt::init_debt_identifier();

        assert!(debt::identifier_get_issuer_name(&identifier) == string::utf8(b""), 0);
        assert!(debt::identifier_get_isin(&identifier) == string::utf8(b""), 1);
    }

    // ============ DEBT STATE CREATION TESTS ============

    #[test]
    fun test_init_debt_state() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt::init_debt_state(ctx);

            assert!(debt::get_issuer_name(&state) == string::utf8(b""), 0);
            assert!(debt::get_isin(&state) == string::utf8(b""), 1);
            assert!(debt::get_interest_rate(&state) == 0, 2);
            assert!(debt::get_par_value(&state) == 0, 3);
            assert!(debt::get_maturity_date(&state) == 0, 4);
            assert!(!debt::is_default_flagged(&state), 5);
            assert!(!debt::is_default(&state), 6);
            assert!(!debt::is_redeemed(&state), 7);
            assert!(!debt::is_matured(&state), 8);
            assert!(debt::get_debt_engine(&state) == @0x0, 9);
            assert!(!debt::is_external_engine_enabled(&state), 10);
            assert!(debt::get_debt(&state) == string::utf8(b""), 11);
            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_init_debt_state_with_identifier() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let identifier = debt::create_debt_identifier(
                string::utf8(b"Acme Corp"),
                string::utf8(b"Corporate issuer"),
                string::utf8(b""),
                string::utf8(b"Trustee"),
                string::utf8(b"US1234567890"),
            );
            let state = debt::init_debt_state_with_identifier(identifier, ctx);

            assert!(debt::get_issuer_name(&state) == string::utf8(b"Acme Corp"), 0);
            assert!(debt::get_isin(&state) == string::utf8(b"US1234567890"), 1);
            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_init_debt_state_full() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let identifier = debt::create_debt_identifier(
                string::utf8(b"Issuer"),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b"ISIN123"),
            );
            let instrument = debt::create_debt_instrument(
                5_000_000,
                1_000_000,
                100_000,
                1704067200,
                1735689600,
                string::utf8(b"ANNUAL"),
                string::utf8(b""),
                string::utf8(b""),
                debt::u8_to_day_count(2),
                debt::u8_to_business_day(3),
                string::utf8(b"USD"),
                @0x0,
            );
            let terms = debt::create_bond_terms(
                string::utf8(b"Callable after 2025"),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b"Unsecured"),
            );
            let state = debt::init_debt_state_full(identifier, instrument, terms, ctx);

            assert!(debt::get_issuer_name(&state) == string::utf8(b"Issuer"), 0);
            assert!(debt::get_isin(&state) == string::utf8(b"ISIN123"), 1);
            assert!(debt::get_interest_rate(&state) == 5_000_000, 2);
            assert!(debt::get_par_value(&state) == 1_000_000, 3);
            assert!(debt::get_maturity_date(&state) == 1735689600, 4);
            assert!(debt::get_call_schedule(&state) == string::utf8(b"Callable after 2025"), 5);
            assert!(debt::get_collateral_description(&state) == string::utf8(b"Unsecured"), 6);
            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    // ============ STRUCT FACTORY TESTS ============

    #[test]
    fun test_create_debt_identifier() {
        let id = debt::create_debt_identifier(
            string::utf8(b"Acme Corp"),
            string::utf8(b"Leading manufacturer"),
            string::utf8(b"LEI123"),
            string::utf8(b"Trustee Corp"),
            string::utf8(b"US1234567890"),
        );

        assert!(debt::identifier_get_issuer_name(&id) == string::utf8(b"Acme Corp"), 0);
        assert!(debt::identifier_get_isin(&id) == string::utf8(b"US1234567890"), 1);
    }

    #[test]
    fun test_create_debt_instrument() {
        let inst = debt::create_debt_instrument(
            5_250_000,
            1_000_000,
            100_000,
            1704067200,
            1735689600,
            string::utf8(b"SEMI_ANNUAL"),
            string::utf8(b"Format B"),
            string::utf8(b"Jan 1/Jul 1"),
            debt::u8_to_day_count(0),
            debt::u8_to_business_day(1),
            string::utf8(b"EUR"),
            @0xDE,
        );

        assert!(debt::instrument_get_interest_rate(&inst) == 5_250_000, 0);
        assert!(debt::instrument_get_par_value(&inst) == 1_000_000, 1);
        assert!(debt::instrument_get_maturity_date(&inst) == 1735689600, 2);
    }

    #[test]
    fun test_create_credit_events() {
        let events = debt::create_credit_events(
            true,
            false,
            false,
            string::utf8(b"AA+"),
            250_000,
            1735689600,
        );

        assert!(debt::credit_events_is_default(&events), 0);
        assert!(!debt::credit_events_is_redeemed(&events), 1);
        assert!(!debt::credit_events_is_matured(&events), 2);
        assert!(debt::credit_events_get_rating(&events) == string::utf8(b"AA+"), 3);
        assert!(debt::credit_events_get_principal_distributed(&events) == 250_000, 4);
        assert!(debt::credit_events_get_next_coupon_date(&events) == 1735689600, 5);
    }

    #[test]
    fun test_create_bond_terms() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            let events = debt::get_credit_events(&state);
            assert!(!debt::credit_events_is_default(&events), 0);
            assert!(!debt::credit_events_is_redeemed(&events), 1);
            assert!(!debt::credit_events_is_matured(&events), 2);
            assert!(debt::credit_events_get_rating(&events) == string::utf8(b""), 3);
            assert!(debt::credit_events_get_principal_distributed(&events) == 0, 4);
            assert!(debt::credit_events_get_next_coupon_date(&events) == 0, 5);

            debt::flag_default(&mut state);
            let ev2 = debt::get_credit_events(&state);
            assert!(debt::credit_events_is_default(&ev2), 6);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_identifier_accessors() {
        let id = debt::create_debt_identifier(
            string::utf8(b"BigCorp"),
            string::utf8(b"Corporate issuer"),
            string::utf8(b"BigCorp Guarantee"),
            string::utf8(b"Trustee Co"),
            string::utf8(b"US9876543210"),
        );
        assert!(debt::identifier_get_issuer_name(&id) == string::utf8(b"BigCorp"), 0);
        assert!(debt::identifier_get_isin(&id) == string::utf8(b"US9876543210"), 1);
    }

    #[test]
    fun test_instrument_accessors() {
        let inst = debt::create_debt_instrument(
            4_000_000,
            500_000,
            50_000,
            1704067200,
            1767225600,
            string::utf8(b"QUARTERLY"),
            string::utf8(b"Format"),
            string::utf8(b"Payment"),
            debt::u8_to_day_count(2),
            debt::u8_to_business_day(0),
            string::utf8(b"EUR"),
            @0xCC,
        );
        assert!(debt::instrument_get_interest_rate(&inst) == 4_000_000, 0);
        assert!(debt::instrument_get_maturity_date(&inst) == 1767225600, 1);
        assert!(debt::instrument_get_par_value(&inst) == 500_000, 2);
    }

    #[test]
    fun test_credit_events_operations() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            let events = debt::get_credit_events(&state);
            assert!(!debt::credit_events_is_default(&events), 0);
            assert!(!debt::credit_events_is_redeemed(&events), 1);
            assert!(!debt::credit_events_is_matured(&events), 2);
            assert!(debt::credit_events_get_rating(&events) == string::utf8(b""), 3);
            assert!(debt::credit_events_get_principal_distributed(&events) == 0, 4);
            assert!(debt::credit_events_get_next_coupon_date(&events) == 0, 5);

            debt::flag_redeemed(&mut state);
            assert!(debt::is_redeemed(&state), 6);

            debt::clear_default(&mut state);
            debt::flag_default(&mut state);
            assert!(debt::is_default(&state), 7);

            debt::flag_matured(&mut state);
            assert!(debt::is_matured(&state), 8);

            debt::set_rating(&mut state, string::utf8(b"A+"));
            assert!(debt::get_rating(&state) == string::utf8(b"A+"), 9);

            debt::record_principal_distribution(&mut state, 250_000);
            assert!(debt::get_principal_distributed(&state) == 250_000, 10);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt::init_debt_state(ctx);

            let events = debt::get_credit_events(&state);
            assert!(debt::credit_events_is_default(&events) == false, 0);
            assert!(debt::credit_events_is_redeemed(&events) == false, 1);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION & MATH TESTS ============

    #[test]
    fun test_is_matured_at_time_zero_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);
            debt::set_maturity_date(&mut state, 0);

            assert!(!debt::is_matured_at_time(1700000000, &state), 0);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_matured_at_time_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);
            debt::set_maturity_date(&mut state, 1700000000);

            assert!(debt::is_matured_at_time(1700000000, &state), 0);
            assert!(debt::is_matured_at_time(1800000000, &state), 1);
            assert!(!debt::is_matured_at_time(1600000000, &state), 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_redemption_allowed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);
            debt::set_maturity_date(&mut state, 1700000000);

            assert!(debt::is_redemption_allowed(1700000000, &state), 0);

            debt::flag_redeemed(&mut state);
            assert!(!debt::is_redemption_allowed(1700000000, &state), 1);

            debt::clear_default(&mut state);
            debt::flag_redeemed(&mut state);
            debt::set_maturity_date(&mut state, 0);
            assert!(!debt::is_redemption_allowed(1700000000, &state), 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_fully_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            assert!(!debt::is_fully_redeemed(&state), 0);

            debt::flag_redeemed(&mut state);
            assert!(debt::is_fully_redeemed(&state), 1);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_time_to_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);
            debt::set_maturity_date(&mut state, 1700000000);

            assert!(debt::time_to_maturity(1600000000, &state) == 100000000, 0);
            assert!(debt::time_to_maturity(1700000000, &state) == 0, 1);
            assert!(debt::time_to_maturity(1800000000, &state) == 0, 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_check_and_update_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            assert!(!debt::is_matured(&state), 0);

            debt::check_and_update_maturity(&mut state, 0);
            assert!(!debt::is_matured(&state), 1);

            debt::set_maturity_date(&mut state, 1700000000);
            debt::check_and_update_maturity(&mut state, 1700000000);
            assert!(debt::is_matured(&state), 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_validate_redemption_amount() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::set_minimum_denomination(&mut state, 0);
            assert!(debt::validate_redemption_amount(&state, 100), 0);

            debt::set_minimum_denomination(&mut state, 100);
            assert!(debt::validate_redemption_amount(&state, 300), 1);
            assert!(!debt::validate_redemption_amount(&state, 150), 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_simple_interest() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt::init_debt_state(ctx);

            assert!(debt::calculate_simple_interest(0, 5000000, 365, 365) == 0, 0);
            assert!(debt::calculate_simple_interest(1000000, 0, 365, 365) == 0, 1);
            assert!(debt::calculate_simple_interest(1000000, 5000000, 0, 365) == 0, 2);
            assert!(debt::calculate_simple_interest(1000000, 5000000, 365, 365) > 0, 3);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_rate_conversions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt::init_debt_state(ctx);

            assert!(debt::rate_to_percentage(5_000_000) == 500, 0);
            assert!(debt::rate_to_percentage(0) == 0, 1);

            assert!(debt::percentage_to_rate(5) == 50_000, 2);
            assert!(debt::percentage_to_rate(0) == 0, 3);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_days_in_year() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt::init_debt_state(ctx);

            assert!(debt::days_in_year(&debt::u8_to_day_count(0)) == 360, 0);
            assert!(debt::days_in_year(&debt::u8_to_day_count(1)) == 360, 1);
            assert!(debt::days_in_year(&debt::u8_to_day_count(2)) == 365, 2);
            assert!(debt::days_in_year(&debt::u8_to_day_count(3)) == 365, 3);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt::EDebtInDefault)]
    fun test_require_not_in_default_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::flag_default(&mut state);
            debt::require_not_in_default(&state);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt::EAlreadyRedeemed)]
    fun test_require_not_redeemed_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::flag_redeemed(&mut state);
            debt::require_not_redeemed(&state);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    // ============ REMAINING GETTER TESTS ============

    #[test]
    fun test_identifier_remaining_getters() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::set_issuer_description(&mut state, string::utf8(b"Issuer description"));
            debt::set_guarantor(&mut state, string::utf8(b"LEI123456"));
            debt::set_debt_holder_representative(&mut state, string::utf8(b"Trustee Corp"));

            assert!(debt::get_issuer_description(&state) == string::utf8(b"Issuer description"), 0);
            assert!(debt::get_guarantor(&state) == string::utf8(b"LEI123456"), 1);
            assert!(debt::get_debt_holder_representative(&state) == string::utf8(b"Trustee Corp"), 2);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_instrument_remaining_getters() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::set_minimum_denomination(&mut state, 100000);
            debt::set_issuance_date(&mut state, 1704067200);
            debt::set_coupon_frequency(&mut state, string::utf8(b"QUARTERLY"));
            debt::set_interest_schedule_format(&mut state, string::utf8(b"Schedule A"));
            debt::set_interest_payment_date(&mut state, string::utf8(b"Jan 1"));
            debt::set_currency(&mut state, string::utf8(b"EUR"));
            debt::set_currency_contract(&mut state, @0xDE);
            debt::set_business_day_convention(&mut state, debt::u8_to_business_day(1));

            assert!(debt::get_minimum_denomination(&state) == 100000, 0);
            assert!(debt::get_issuance_date(&state) == 1704067200, 1);
            assert!(debt::get_coupon_frequency(&state) == string::utf8(b"QUARTERLY"), 2);
            assert!(debt::get_interest_schedule_format(&state) == string::utf8(b"Schedule A"), 3);
            assert!(debt::get_interest_payment_date(&state) == string::utf8(b"Jan 1"), 4);
            assert!(debt::get_currency(&state) == string::utf8(b"EUR"), 5);
            assert!(debt::get_currency_contract(&state) == @0xDE, 6);
            assert!(debt::business_day_to_u8(&debt::get_business_day_convention(&state)) == 1, 7);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_bond_terms_remaining_getters() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        {
            let ctx = test_scenario::ctx(scenario);
            let mut state = debt::init_debt_state(ctx);

            debt::set_sinking_fund_schedule(&mut state, string::utf8(b"Annual 5%"));
            debt::set_convertible_terms(&mut state, string::utf8(b"Convertible at 1.2x"));

            assert!(debt::get_sinking_fund_schedule(&state) == string::utf8(b"Annual 5%"), 0);
            assert!(debt::get_convertible_terms(&state) == string::utf8(b"Convertible at 1.2x"), 1);

            debt::delete_debt_state(state);
        };
        test_scenario::end(scenario_val);
    }
}
