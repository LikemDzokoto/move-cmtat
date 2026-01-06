/// Standard CMTAT Test Suite - Comprehensive Testing
/// Tests initialization, minting, burning, transfers, freeze, pause, and snapshots
#[test_only]
module move_cmtat::standard_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin};
    use iota::clock;
    
    use move_cmtat::standard_cmtat::{Self, StandardCMTAT, ComplianceState, AdminCap, MintCap, BurnCap, 
                                      FreezeCap, PauseCap, SnapshotCap};
    use move_cmtat::base;
    use move_cmtat::icmtat;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init_token() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard CMTAT"),
                string::utf8(b"SCMTAT"),
                9,
                1000000,  // Initial supply
                ADMIN,    // Recipient
                ctx
            );
        };

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<StandardCMTAT>(), 0);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 1);
            
            // Verify capabilities were transferred to admin
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 2);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<BurnCap>(scenario), 4);
            assert!(test_scenario::has_most_recent_for_sender<FreezeCap>(scenario), 5);
            assert!(test_scenario::has_most_recent_for_sender<PauseCap>(scenario), 6);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 7);
            
            // Check initial coins were sent to admin
            assert!(test_scenario::has_most_recent_for_sender<Coin<base::CMTAT>>(scenario), 8);
            let initial_coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);
            assert!(base::coin_value(&initial_coins) == 1000000, 9);
            test_scenario::return_to_sender(scenario, initial_coins);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_init_token_zero_supply() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token with zero supply
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard CMTAT"),
                string::utf8(b"SCMTAT"),
                9,
                0,  // Zero initial supply
                ADMIN,
                ctx
            );
        };

        // Verify no initial coins
        test_scenario::next_tx(scenario, ADMIN);
        {
            // Should not have any Coin<CMTAT> since supply was zero
            assert!(!test_scenario::has_most_recent_for_sender<Coin<base::CMTAT>>(scenario), 0);
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
            standard_cmtat::init_token(
                string::utf8(b"Test Token"),
                string::utf8(b"TEST"),
                6,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);

            // Test token info
            assert!(standard_cmtat::name(&token) == string::utf8(b"Test Token"), 0);
            assert!(standard_cmtat::symbol(&token) == string::utf8(b"TEST"), 1);
            assert!(standard_cmtat::decimals(&token) == 6, 2);
            assert!(standard_cmtat::total_supply(&token) == 0, 3);
            
            // Test compliance state
            assert!(!standard_cmtat::paused(&compliance_state), 4);
            assert!(!standard_cmtat::deactivated(&compliance_state), 5);
            assert!(!standard_cmtat::is_frozen(&compliance_state, USER1), 6);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
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
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            // Check total supply increased
            assert!(standard_cmtat::total_supply(&token) == 5000, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<base::CMTAT>>(scenario), 0);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);
            assert!(base::coin_value(&coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_when_paused() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);

            // Pause contract
            standard_cmtat::pause(&pause_cap, &mut compliance_state);

            // Try to mint - should fail
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, pause_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_to_frozen_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            // Freeze USER1
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);

            // Try to mint - should fail
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== BURNING TESTS ==========

    #[test]
    fun test_burn() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with initial supply
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);

            // Verify initial supply
            assert!(standard_cmtat::total_supply(&token) == 10000, 0);

            // Burn half
            standard_cmtat::burn(&mut token, coins, &compliance_state);

            // Verify supply decreased
            assert!(standard_cmtat::total_supply(&token) == 0, 1);

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
            standard_cmtat::init_token(
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

            // Verify not paused initially
            assert!(!standard_cmtat::paused(&compliance_state), 0);

            // Pause
            standard_cmtat::pause(&pause_cap, &mut compliance_state);
            assert!(standard_cmtat::paused(&compliance_state), 1);

            // Unpause
            standard_cmtat::unpause(&pause_cap, &mut compliance_state);
            assert!(!standard_cmtat::paused(&compliance_state), 2);

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
            standard_cmtat::init_token(
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

            // Verify not deactivated initially
            assert!(!standard_cmtat::deactivated(&compliance_state), 0);

            // Deactivate
            standard_cmtat::deactivate_contract(&admin_cap, &mut compliance_state);
            assert!(standard_cmtat::deactivated(&compliance_state), 1);

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
            standard_cmtat::init_token(
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

            // Verify not frozen initially
            assert!(!standard_cmtat::is_frozen(&compliance_state, USER1), 0);

            // Freeze USER1
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);
            assert!(standard_cmtat::is_frozen(&compliance_state, USER1), 1);

            // Unfreeze USER1
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, false);
            assert!(!standard_cmtat::is_frozen(&compliance_state, USER1), 2);

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
            standard_cmtat::init_token(
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

            // Freeze 300 tokens for USER1
            standard_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 300);

            // Unfreeze 100 tokens
            standard_cmtat::unfreeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 100);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION TESTS ==========

    #[test]
    fun test_transfer_validation_allowed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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

            // Validate transfer - should be allowed
            let restriction_code = standard_cmtat::detect_transfer_restriction(
                &compliance_state,
                ADMIN,
                USER1,
                100,
                1000  // from_balance
            );

            assert!(restriction_code == icmtat::restriction_code_valid(), 0);

            let message = standard_cmtat::message_for_transfer_restriction(restriction_code);
            assert!(message == string::utf8(b"Transfer allowed"), 1);

            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_when_paused() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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

            // Pause contract
            standard_cmtat::pause(&pause_cap, &mut compliance_state);

            // Validate transfer - should be restricted
            let restriction_code = standard_cmtat::detect_transfer_restriction(
                &compliance_state,
                ADMIN,
                USER1,
                100,
                1000
            );

            assert!(restriction_code == icmtat::restriction_code_paused(), 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, pause_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_frozen_sender() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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

            // Freeze sender
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, ADMIN, true);

            // Validate transfer - should be restricted
            let restriction_code = standard_cmtat::detect_transfer_restriction(
                &compliance_state,
                ADMIN,
                USER1,
                100,
                1000
            );

            assert!(restriction_code == icmtat::restriction_code_frozen_sender(), 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_frozen_receiver() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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

            // Freeze receiver
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);

            // Validate transfer - should be restricted
            let restriction_code = standard_cmtat::detect_transfer_restriction(
                &compliance_state,
                ADMIN,
                USER1,
                100,
                1000
            );

            assert!(restriction_code == icmtat::restriction_code_frozen_receiver(), 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER EXECUTION TESTS ==========

    #[test]
    fun test_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with initial supply
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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
            standard_cmtat::transfer(&compliance_state, coins, USER1, ctx);

            test_scenario::return_shared(compliance_state);
        };

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<base::CMTAT>>(scenario), 0);
            let user_coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);
            assert!(base::coin_value(&user_coins) == 5000, 1);
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
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));

            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMINISTRATIVE TESTS ==========

    #[test]
    fun test_set_terms() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
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
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            standard_cmtat::set_terms(&admin_cap, &mut token, string::utf8(b"New Terms"));
            standard_cmtat::set_information(&admin_cap, &mut token, string::utf8(b"New Info"));
            standard_cmtat::set_token_id(&admin_cap, &mut token, string::utf8(b"TOKEN123"));
            standard_cmtat::set_document_uri(&admin_cap, &mut token, string::utf8(b"https://example.com"));

            assert!(standard_cmtat::document_uri(&token) == string::utf8(b"https://example.com"), 0);

            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }
}
