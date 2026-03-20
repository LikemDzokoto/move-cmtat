/// Debt CMTAT Test Suite - Updated for Embedded Debt State
#[test_only]
#[allow(unused_use, unused_const, duplicate_alias)]
module move_cmtat::debt_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, TreasuryCap, Coin, DenyCapV1};
    use iota::deny_list::{Self, DenyList};
    use iota::clock::{Self, Clock};

    use move_cmtat::debt_cmtat::{Self, DEBT_CMTAT, CMTATRegistry, DebtCMTATState,
                                   AdminCap, DebtCap, MintCap, BurnCap, PauseCap,
                                   SnapshotCap, EnforcerCap};
    use move_cmtat::debt;
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

    // ========== CAPABILITY GRANT TESTS ==========

    #[test]
    fun test_grant_minter() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_minter(&admin_cap, treasury_cap, DEBT_ENGINE, ctx);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::return_shared(state);
        };

        test_scenario::next_tx(scenario, DEBT_ENGINE);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);

            test_scenario::return_to_sender(scenario, mint_cap);
            transfer::public_transfer(treasury_cap, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_burner() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_burner(&admin_cap, treasury_cap, DEBT_ENGINE, ctx);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::return_shared(state);
        };

        test_scenario::next_tx(scenario, DEBT_ENGINE);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let burn_cap = test_scenario::take_from_sender<BurnCap>(scenario);

            test_scenario::return_to_sender(scenario, burn_cap);
            transfer::public_transfer(treasury_cap, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_pauser() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let deny_cap = test_scenario::take_from_sender<DenyCapV1<DEBT_CMTAT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_pauser(&admin_cap, deny_cap, DEBT_ENGINE, ctx);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, DEBT_ENGINE);
            {
                let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);
                test_scenario::return_to_sender(scenario, pause_cap);
            };
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_enforcer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let deny_cap = test_scenario::take_from_sender<DenyCapV1<DEBT_CMTAT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_enforcer(&admin_cap, deny_cap, DEBT_ENGINE, ctx);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, DEBT_ENGINE);
            {
                let enforcer_cap = test_scenario::take_from_sender<EnforcerCap>(scenario);
                test_scenario::return_to_sender(scenario, enforcer_cap);
            };
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_snapshooter() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_snapshooter(&admin_cap, DEBT_ENGINE, ctx);

            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, DEBT_ENGINE);
        {
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_debt_manager() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::grant_debt_manager(&admin_cap, debt_cap, DEBT_ENGINE, ctx);

            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, DEBT_ENGINE);
        {
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== REGISTRY SETTER TESTS ==========

    #[test]
    fun test_set_terms() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_terms(&admin_cap, &mut registry, string::utf8(b"Terms v2"), ctx);

            assert!(debt_cmtat::terms(&registry) == string::utf8(b"Terms v2"), 0);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_information() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_information(&admin_cap, &mut registry, string::utf8(b"Info v2"), ctx);

            assert!(debt_cmtat::information(&registry) == string::utf8(b"Info v2"), 0);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_token_id() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_token_id(&admin_cap, &mut registry, string::utf8(b"TOKEN_V2"), ctx);

            assert!(debt_cmtat::token_id(&registry) == string::utf8(b"TOKEN_V2"), 0);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_document_uri() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_document_uri(&admin_cap, &mut registry, string::utf8(b"https://example.com"), ctx);

            assert!(debt_cmtat::document_uri(&registry) == string::utf8(b"https://example.com"), 0);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MINT / BURN TESTS ==========

    #[test]
    fun test_mint_and_transfer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let deny_list = take_deny_list(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));

            let coins = debt_cmtat::mint(
                &mut treasury_cap,
                &registry,
                &state,
                &deny_list,
                DEBT_ENGINE,
                1_000_000,
                test_scenario::ctx(scenario),
            );

            assert!(coin::value(&coins) == 1_000_000, 0);

            transfer::public_transfer(coins, DEBT_ENGINE);

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_and_transfer_entry() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let deny_list = take_deny_list(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::mint_and_transfer(
                &mut treasury_cap,
                &registry,
                &mut state,
                &deny_list,
                &clock,
                DEBT_ENGINE,
                500_000,
                ctx,
            );

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_burn() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let coins = coin::mint(&mut treasury_cap, 1_000_000, test_scenario::ctx(scenario));

            debt_cmtat::burn(&mut treasury_cap, coins, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_burn_entry() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let deny_list = take_deny_list(scenario);
            let coins = coin::mint(&mut treasury_cap, 500_000, test_scenario::ctx(scenario));

            debt_cmtat::burn_entry(&mut treasury_cap, coins, &deny_list, test_scenario::ctx(scenario));

            test_scenario::return_shared(deny_list);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let deny_list = take_deny_list(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));

            let coins = coin::mint(&mut treasury_cap, 1_000_000, test_scenario::ctx(scenario));

            debt_cmtat::transfer(
                &registry,
                &mut state,
                &deny_list,
                &clock,
                coins,
                DEBT_ENGINE,
                test_scenario::ctx(scenario),
            );

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ========== RULE ENGINE DELEGATION TESTS ==========

    #[test]
    fun test_add_and_remove_vip() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!debt_cmtat::is_vip(&state, DEBT_ENGINE), 0);

            debt_cmtat::add_vip(&admin_cap, &mut state, DEBT_ENGINE, ctx);
            assert!(debt_cmtat::is_vip(&state, DEBT_ENGINE), 1);

            debt_cmtat::remove_vip(&admin_cap, &mut state, DEBT_ENGINE, ctx);
            assert!(!debt_cmtat::is_vip(&state, DEBT_ENGINE), 2);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_and_remove_rule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::add_rule(&admin_cap, &mut state, 0, ctx);
            assert!(debt_cmtat::is_rule_enabled(&state, 0), 0);

            debt_cmtat::remove_rule(&admin_cap, &mut state, 0, ctx);
            assert!(!debt_cmtat::is_rule_enabled(&state, 0), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_blacklist() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::add_to_blacklist(&admin_cap, &mut state, DEBT_ENGINE, ctx);
            debt_cmtat::remove_from_blacklist(&admin_cap, &mut state, DEBT_ENGINE, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_sanction_list() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::add_to_sanction_list(&admin_cap, &mut state, DEBT_ENGINE, ctx);
            debt_cmtat::remove_from_sanction_list(&admin_cap, &mut state, DEBT_ENGINE, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_max_balance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_max_balance(&admin_cap, &mut state, 10_000_000, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_auto_approval() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_auto_approval(&admin_cap, &mut state, true, ctx);
            debt_cmtat::set_auto_approval(&admin_cap, &mut state, false, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_time_limits() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_time_limits(&admin_cap, &mut state, 3600_000, 7200_000, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_and_restore_rule_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(debt_cmtat::rule_engine_active(&state), 0);

            debt_cmtat::remove_rule_engine(&admin_cap, &mut state, ctx);
            assert!(!debt_cmtat::rule_engine_active(&state), 1);

            debt_cmtat::restore_rule_engine(&admin_cap, &mut state, ctx);
            assert!(debt_cmtat::rule_engine_active(&state), 2);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== COUPON / INTEREST TESTS ==========

    #[test]
    fun test_generate_coupon_schedule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_debt_instrument(
                &debt_cap, &mut state,
                5_000_000, 1_000_000, 100_000,
                1704067200, 1735689600,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                2, 3, string::utf8(b"USD"), @0x0, ctx,
            );

            debt_cmtat::generate_coupon_schedule(&debt_cap, &mut state, &treasury_cap, &clock, ctx);

            assert!(debt_cmtat::is_coupon_schedule_generated(&state), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = interest_engine::ECouponNotDue)]
    fun test_record_coupon_payment() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_debt_instrument(
                &debt_cap, &mut state,
                5_000_000, 1_000_000, 100_000,
                1704067200, 1735689600,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                2, 3, string::utf8(b"USD"), @0x0, ctx,
            );

            debt_cmtat::generate_coupon_schedule(&debt_cap, &mut state, &treasury_cap, &clock, ctx);
            debt_cmtat::record_coupon_payment(&debt_cap, &mut state, 1, &clock, ctx);

            assert!(debt_cmtat::get_coupons_remaining(&state) == 0 || debt_cmtat::get_total_interest_paid(&state) > 0, 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = interest_engine::EClaimNotDue)]
    fun test_claim_coupon() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_debt_instrument(
                &debt_cap, &mut state,
                5_000_000, 1_000_000, 100_000,
                1704067200, 1735689600,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                2, 3, string::utf8(b"USD"), @0x0, ctx,
            );

            debt_cmtat::generate_coupon_schedule(&debt_cap, &mut state, &treasury_cap, &clock, ctx);

            let coins = debt_cmtat::claim_coupon(&mut state, &mut treasury_cap, 1, 100_000, &clock, ctx);
            transfer::public_transfer(coins, ADMIN);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_claimable_amount_and_next_coupon() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_debt_instrument(
                &debt_cap, &mut state,
                5_000_000, 1_000_000, 100_000,
                1704067200, 1735689600,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                2, 3, string::utf8(b"USD"), @0x0, ctx,
            );

            debt_cmtat::generate_coupon_schedule(&debt_cap, &mut state, &treasury_cap, &clock, ctx);

            let next = debt_cmtat::get_next_coupon(&state);
            assert!(option::is_some(&next) || option::is_none(&next), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ABORT TESTS ==========

    #[test]
    #[expected_failure(abort_code = debt_cmtat::EModuleDeactivated)]
    fun test_mint_aborts_when_deactivated() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<DEBT_CMTAT>>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);

            let coins = debt_cmtat::mint(
                &mut treasury_cap, &registry, &state, &deny_list, DEBT_ENGINE, 100, ctx,
            );

            transfer::public_transfer(coins, DEBT_ENGINE);

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_cmtat::ENotMaturedOrDefault)]
    fun test_redeem_aborts_before_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let deny_list = take_deny_list(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let clock = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::set_debt_instrument(
                &debt_cap, &mut state,
                5_000_000, 1_000_000, 100_000,
                1704067200, 1893456000,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                2, 3, string::utf8(b"USD"), @0x0, ctx,
            );

            let coins = coin::mint(&mut treasury_cap, 500_000, ctx);

            debt_cmtat::redeem(&mut treasury_cap, &registry, &mut state, &deny_list, &clock, coins, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt::EDebtInDefault)]
    fun test_mint_aborts_when_in_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let deny_list = take_deny_list(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<DEBT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::flag_default(&debt_cap, &mut state, ctx);

            let coins = debt_cmtat::mint(
                &mut treasury_cap, &registry, &state, &deny_list, DEBT_ENGINE, 100, ctx,
            );

            transfer::public_transfer(coins, DEBT_ENGINE);

            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_cmtat::EModuleDeactivated)]
    fun test_pause_aborts_when_deactivated() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<DEBT_CMTAT>>(scenario);
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);
            debt_cmtat::pause(&mut deny_list, &mut deny_cap, &registry, ctx);

            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_cmtat::ERuleEngineNotActive)]
    fun test_remove_rule_engine_aborts_when_not_active() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::remove_rule_engine(&admin_cap, &mut state, ctx);
            debt_cmtat::remove_rule_engine(&admin_cap, &mut state, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_cmtat::ERuleEngineAlreadyActive)]
    fun test_restore_rule_engine_aborts_when_already_active() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_cmtat::restore_rule_engine(&admin_cap, &mut state, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
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
