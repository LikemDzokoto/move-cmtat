/// Debt CMTAT Test Suite - Comprehensive Testing for Debt Securities
/// Tests debt information, credit events, default flagging, and all standard features
#[test_only]
module move_cmtat::debt_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin};
    use iota::clock;
    
    use move_cmtat::debt_cmtat::{Self, DebtCMTAT, ComplianceState, AdminCap, MintCap, BurnCap,
                                   FreezeCap, PauseCap, DebtCap, SnapshotCap};
    use move_cmtat::base;
    use move_cmtat::icmtat;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const DEBT_ENGINE: address = @0xDEBT;

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init_token() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Debt CMTAT"),
                string::utf8(b"DCMTAT"),
                9,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Verify shared objects and capabilities
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<DebtCMTAT>(), 0);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 1);
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 2);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<DebtCap>(scenario), 4);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 5);
        };

        test_scenario::end(scenario_val);
    }

    // ========== DEBT MANAGEMENT TESTS ==========

    #[test]
    fun test_set_debt() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let debt_info = string::utf8(b"5% Annual Coupon Bond, Maturity 2030");
            debt_cmtat::set_debt(&debt_cap, &mut compliance_state, debt_info);

            assert!(debt_cmtat::debt(&compliance_state) == debt_info, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_credit_events() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let events = string::utf8(b"Coupon payment on 2024-06-15: $50,000");
            debt_cmtat::set_credit_events(&debt_cap, &mut compliance_state, events);

            assert!(debt_cmtat::credit_events(&compliance_state) == events, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_debt_engine() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== DEFAULT FLAG TESTS ==========

    #[test]
    fun test_flag_default() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            // Verify not in default initially
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 0);

            // Flag default
            debt_cmtat::flag_default(&debt_cap, &mut compliance_state);
            assert!(debt_cmtat::is_default_flagged(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_when_defaulted() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            // Flag default
            debt_cmtat::flag_default(&debt_cap, &mut compliance_state);

            // Try to mint - should fail
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 1000, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MINTING TESTS ==========

    #[test]
    fun test_mint() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            assert!(debt_cmtat::total_supply(&token) == 5000, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== BURNING TESTS ==========

    #[test]
    fun test_burn() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with supply
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                10000,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);

            assert!(debt_cmtat::total_supply(&token) == 10000, 0);

            debt_cmtat::burn(&mut token, coins, &compliance_state);

            assert!(debt_cmtat::total_supply(&token) == 0, 1);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== PAUSE TESTS ==========

    #[test]
    fun test_pause_unpause() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);

            assert!(!debt_cmtat::paused(&compliance_state), 0);

            debt_cmtat::pause(&pause_cap, &mut compliance_state);
            assert!(debt_cmtat::paused(&compliance_state), 1);

            debt_cmtat::unpause(&pause_cap, &mut compliance_state);
            assert!(!debt_cmtat::paused(&compliance_state), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, pause_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deactivate_contract() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            assert!(!debt_cmtat::deactivated(&compliance_state), 0);

            debt_cmtat::deactivate_contract(&admin_cap, &mut compliance_state);
            assert!(debt_cmtat::deactivated(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== FREEZE TESTS ==========

    #[test]
    fun test_freeze_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            assert!(!debt_cmtat::is_frozen(&compliance_state, USER1), 0);

            debt_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);
            assert!(debt_cmtat::is_frozen(&compliance_state, USER1), 1);

            debt_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, false);
            assert!(!debt_cmtat::is_frozen(&compliance_state, USER1), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_freeze_partial_tokens() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            debt_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 500);
            debt_cmtat::unfreeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 200);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER TESTS ==========

    #[test]
    fun test_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with supply
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                5000,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::transfer(&compliance_state, coins, USER1, ctx);

            test_scenario::return_shared(compliance_state);
        };

        // Verify USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            let user_coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);
            assert!(base::coin_value(&user_coins) == 5000, 0);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SNAPSHOT TESTS ==========

    #[test]
    fun test_snapshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== VIEW FUNCTION TESTS ==========

    #[test]
    fun test_view_functions() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Debt Token"),
                string::utf8(b"DEBT"),
                6,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);

            assert!(debt_cmtat::name(&token) == string::utf8(b"Debt Token"), 0);
            assert!(debt_cmtat::symbol(&token) == string::utf8(b"DEBT"), 1);
            assert!(debt_cmtat::decimals(&token) == 6, 2);
            assert!(debt_cmtat::total_supply(&token) == 0, 3);
            assert!(!debt_cmtat::paused(&compliance_state), 4);
            assert!(!debt_cmtat::deactivated(&compliance_state), 5);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 6);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMINISTRATIVE FUNCTION TESTS ==========

    #[test]
    fun test_admin_functions() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Test"),
                string::utf8(b"TST"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            debt_cmtat::set_terms(&admin_cap, &mut token, string::utf8(b"Bond Terms"));
            debt_cmtat::set_information(&admin_cap, &mut token, string::utf8(b"Bond Info"));
            debt_cmtat::set_token_id(&admin_cap, &mut token, string::utf8(b"BOND123"));
            debt_cmtat::set_document_uri(&admin_cap, &mut token, string::utf8(b"https://bonds.example.com"));

            assert!(debt_cmtat::document_uri(&token) == string::utf8(b"https://bonds.example.com"), 0);

            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== COMPREHENSIVE DEBT WORKFLOW TEST ==========

    #[test]
    fun test_comprehensive_debt_workflow() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond 2030"),
                string::utf8(b"BOND30"),
                9,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);

            // Set debt information
            debt_cmtat::set_debt(&debt_cap, &mut compliance_state, 
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"));
            
            // Set credit events
            debt_cmtat::set_credit_events(&debt_cap, &mut compliance_state,
                string::utf8(b"2024-06-30: Coupon payment $55,000"));
            
            // Set debt engine
            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            // Mint bonds
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 1000000, ctx);

            // Verify all settings
            assert!(debt_cmtat::debt(&compliance_state) == 
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"), 0);
            assert!(debt_cmtat::credit_events(&compliance_state) == 
                string::utf8(b"2024-06-30: Coupon payment $55,000"), 1);
            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 2);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 3);
            assert!(debt_cmtat::total_supply(&token) == 1000000, 4);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        test_scenario::end(scenario_val);
    }
}
