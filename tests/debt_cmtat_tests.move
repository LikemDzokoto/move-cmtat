/// Debt CMTAT Test Suite - Updated for Embedded Debt State
#[test_only]
#[allow(unused_use, unused_const, duplicate_alias)]
module move_cmtat::debt_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::TreasuryCap;
    use iota::deny_list::{Self, DenyList};
    use iota::clock::Clock;

    use move_cmtat::debt_cmtat::{Self, DEBT_CMTAT, CMTATRegistry, DebtCMTATState,
                                   AdminCap, DebtCap};
    use move_cmtat::interest_engine;

    const ADMIN: address = @0xAD;
    const DEBT_ENGINE: address = @0xDE;

    fun setup(scenario: &mut test_scenario::Scenario) {
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            deny_list::create_for_test(ctx);
        };
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };
    }

    fun take_deny_list(scenario: &test_scenario::Scenario): DenyList {
        test_scenario::take_shared<DenyList>(scenario)
    }

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<CMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<DebtCMTATState>(), 1);
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 2);
        };

        test_scenario::end(scenario_val);
    }

    // ========== DEBT IDENTIFIER TESTS ==========

    #[test]
    fun test_set_debt_identifier() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_identifier(
                &debt_cap,
                &mut state,
                string::utf8(b"Acme Corp"),
                string::utf8(b"Leading manufacturer"),
                string::utf8(b""),
                string::utf8(b"Holder Rep"),
                string::utf8(b"US1234567890"),
                ctx
            );

            assert!(debt_cmtat::get_issuer_name(&state) == string::utf8(b"Acme Corp"), 0);
            assert!(debt_cmtat::get_isin(&state) == string::utf8(b"US1234567890"), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== DEBT INSTRUMENT TESTS ==========

    #[test]
    fun test_set_debt_instrument() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_instrument(
                &debt_cap,
                &mut state,
                5_250_000,  // 5.25% interest rate (fixed-point)
                1_000_000,  // par value: 1000000 in smallest units
                1_000_000,  // minimum denomination
                1704067200,  // issuance date (2024-01-01)
                1735689600,  // maturity date (2025-01-01)
                string::utf8(b"ANNUAL"),
                string::utf8(b"Format A"),
                string::utf8(b"Start date/end date/period"),
                2,  // day count convention: Actual/365
                3,  // business day convention: Unadjusted
                string::utf8(b"USD"),
                @0x0,
                ctx
            );

            assert!(debt_cmtat::get_interest_rate(&state) == 5_250_000, 0);
            assert!(debt_cmtat::get_par_value(&state) == 1_000_000, 1);
            assert!(debt_cmtat::get_minimum_denomination(&state) == 1_000_000, 2);
            assert!(debt_cmtat::get_maturity_date(&state) == 1735689600, 3);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_bond_terms() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_bond_terms(
                &debt_cap,
                &mut state,
                string::utf8(b"Callable after 2025-01-01"),
                string::utf8(b"Puttable after 2024-07-01"),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b"Unsecured"),
                ctx
            );

            assert!(!debt_cmtat::is_default_flagged(&state), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== CREDIT EVENTS TESTS ==========

    #[test]
    fun test_set_rating() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_rating(&debt_cap, &mut state, string::utf8(b"AAA"), ctx);

            assert!(debt_cmtat::get_rating(&state) == string::utf8(b"AAA"), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            assert!(!debt_cmtat::is_default_flagged(&state), 0);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::flag_default(&debt_cap, &mut state, ctx);
            assert!(debt_cmtat::is_default_flagged(&state), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            assert!(!debt_cmtat::is_redeemed(&state), 0);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::flag_redeemed(&debt_cap, &mut state, ctx);
            assert!(debt_cmtat::is_redeemed(&state), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MATURITY TESTS ==========

    #[test]
    fun test_is_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_instrument(
                &debt_cap,
                &mut state,
                5_000_000,
                1_000_000,
                1_000_000,
                900_000_000,  // issuance: 1998
                1_000_000_000,  // maturity: 2001 (in the past)
                string::utf8(b"ANNUAL"),
                string::utf8(b""),
                string::utf8(b""),
                2,
                3,
                string::utf8(b"USD"),
                @0x0,
                ctx
            );

            assert!(debt_cmtat::is_matured(&state, 1_500_000_000), 0);  // 2017 > 2001
            assert!(!debt_cmtat::is_matured(&state, 500_000_000), 1);  // 1985 < 2001

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_maturity_not_reached() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_instrument(
                &debt_cap,
                &mut state,
                5_000_000,
                1_000_000,
                1,
                1704067200,  // 2024-01-01
                1893456000,  // 2030-01-01 (future)
                string::utf8(b"ANNUAL"),
                string::utf8(b""),
                string::utf8(b""),
                2,
                3,
                string::utf8(b"USD"),
                @0x0,
                ctx
            );

            assert!(!debt_cmtat::is_matured(&state, 1704067200), 0);
            assert!(!debt_cmtat::is_matured(&state, 1711977600), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== LEGACY TESTS ==========

    #[test]
    fun test_legacy_set_debt() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt(&debt_cap, &mut state, string::utf8(b"5% Annual Bond"), ctx);

            assert!(debt_cmtat::debt_info(&state) == string::utf8(b"5% Annual Bond"), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_legacy_set_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_credit_events(
                &debt_cap,
                &mut state,
                false,
                false,
                false,
                string::utf8(b"AAA"),
                0,
                1704067200,
                ctx,
            );

            let _events = debt_cmtat::credit_events(&state);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_debt_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_engine(&debt_cap, &mut state, DEBT_ENGINE, ctx);

            assert!(debt_cmtat::debt_engine(&state) == DEBT_ENGINE, 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== INTEREST ENGINE TESTS ==========

    #[test]
    fun test_interest_engine_initial_state() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);

            assert!(!debt_cmtat::is_coupon_schedule_generated(&state), 0);
            assert!(debt_cmtat::get_coupons_remaining(&state) == 0, 1);
            assert!(debt_cmtat::get_total_interest_paid(&state) == 0, 2);

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_coupon_views_no_schedule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);

            let unpaid = debt_cmtat::get_unpaid_coupons(&state);
            assert!(vector::length(&unpaid) == 0, 0);

            let upcoming = debt_cmtat::get_upcoming_coupons(&state, 1700000000);
            assert!(vector::length(&upcoming) == 0, 1);

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_interest_engine_views() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);

            assert!(debt_cmtat::get_total_interest_paid(&state) == 0, 0);
            assert!(debt_cmtat::get_coupons_remaining(&state) == 0, 1);
            assert!(!debt_cmtat::is_coupon_schedule_generated(&state), 2);

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== VIEW FUNCTIONS TEST ==========

    #[test]
    fun test_view_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let deny_list = take_deny_list(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!debt_cmtat::is_paused(&deny_list, ctx), 0);
            assert!(!debt_cmtat::is_default_flagged(&state), 1);

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== INTEGRATION TEST ==========

    #[test]
    fun test_debt_workflow_integration() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            // Set debt identifier
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_identifier(
                &debt_cap,
                &mut state,
                string::utf8(b"Acme Corp"),
                string::utf8(b"Corporate Bond Issuer"),
                string::utf8(b""),
                string::utf8(b"Trustee Corp"),
                string::utf8(b"US1234567890"),
                ctx
            );

            // Set debt instrument
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_debt_instrument(
                &debt_cap,
                &mut state,
                5_500_000,
                1_000_000,
                100_000,
                1704067200,
                1767225600,
                string::utf8(b"ANNUAL"),
                string::utf8(b"Format A"),
                string::utf8(b"Annual payments"),
                2,
                3,
                string::utf8(b"USD"),
                @0x0,
                ctx
            );

            // Set rating
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::set_rating(&debt_cap, &mut state, string::utf8(b"AA+"), ctx);

            // Verify all set
            assert!(debt_cmtat::get_issuer_name(&state) == string::utf8(b"Acme Corp"), 0);
            assert!(debt_cmtat::get_isin(&state) == string::utf8(b"US1234567890"), 1);
            assert!(debt_cmtat::get_interest_rate(&state) == 5_500_000, 2);
            assert!(debt_cmtat::get_par_value(&state) == 1_000_000, 3);
            assert!(debt_cmtat::get_rating(&state) == string::utf8(b"AA+"), 4);
            assert!(!debt_cmtat::is_default_flagged(&state), 5);
            assert!(!debt_cmtat::is_redeemed(&state), 6);
            assert!(!debt_cmtat::is_matured(&state, 1711977600), 7);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }
}
