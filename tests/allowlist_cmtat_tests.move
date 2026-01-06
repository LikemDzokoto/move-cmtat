/// Allowlist CMTAT Test Suite - Comprehensive Testing
/// Tests initialization, minting, burning, transfers, freeze, pause, allowlist, and snapshots
#[test_only]
module move_cmtat::allowlist_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin};
    use iota::clock;
    
    use move_cmtat::allowlist_cmtat::{Self, AllowlistCMTAT, ComplianceState, AdminCap, MintCap, BurnCap, 
                                       FreezeCap, PauseCap, AllowlistCap, SnapshotCap};
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
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist CMTAT"),
                string::utf8(b"ACMTAT"),
                9,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Verify shared objects and capabilities
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<AllowlistCMTAT>(), 0);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 1);
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 2);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<AllowlistCap>(scenario), 4);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ALLOWLIST MANAGEMENT TESTS ==========

    #[test]
    fun test_allowlist_enable_disable() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            // Verify disabled initially
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 0);

            // Enable allowlist
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);
            assert!(allowlist_cmtat::allowlist_enabled(&compliance_state), 1);

            // Disable allowlist
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, false);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_address_allowlist() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            // Enable allowlist
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            // Add USER1 to allowlist
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true);
            assert!(allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 0);
            assert!(!allowlist_cmtat::is_allowlisted(&compliance_state, USER2), 1);

            // Remove USER1 from allowlist
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, false);
            assert!(!allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MINTING WITH ALLOWLIST TESTS ==========

    #[test]
    fun test_mint_to_allowlisted_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            // Enable allowlist and add USER1
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true);

            // Mint to allowlisted address
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            assert!(allowlist_cmtat::total_supply(&token) == 5000, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_to_non_allowlisted_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            // Enable allowlist but don't add USER1
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            // Try to mint to non-allowlisted address - should fail
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 5000, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER WITH ALLOWLIST TESTS ==========

    #[test]
    fun test_transfer_to_allowlisted_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with supply
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);

            // Enable allowlist and add USER1
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true);

            // Transfer to allowlisted address
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::transfer(&compliance_state, coins, USER1, ctx);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<base::CMTAT>>(scenario), 0);
            let user_coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);
            assert!(base::coin_value(&user_coins) == 10000, 1);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_transfer_to_non_allowlisted_address() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize with supply
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);
            let coins = test_scenario::take_from_sender<Coin<base::CMTAT>>(scenario);

            // Enable allowlist but don't add USER1
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            // Try to transfer to non-allowlisted address - should fail
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::transfer(&compliance_state, coins, USER1, ctx);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
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
            allowlist_cmtat::init_token(
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

            // Freeze and unfreeze
            allowlist_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);
            assert!(allowlist_cmtat::is_frozen(&compliance_state, USER1), 0);

            allowlist_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, false);
            assert!(!allowlist_cmtat::is_frozen(&compliance_state, USER1), 1);

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
            allowlist_cmtat::init_token(
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

            // Freeze and unfreeze partial tokens
            allowlist_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 500);
            allowlist_cmtat::unfreeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 200);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
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
            allowlist_cmtat::init_token(
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

            assert!(!allowlist_cmtat::paused(&compliance_state), 0);

            allowlist_cmtat::pause(&pause_cap, &mut compliance_state);
            assert!(allowlist_cmtat::paused(&compliance_state), 1);

            allowlist_cmtat::unpause(&pause_cap, &mut compliance_state);
            assert!(!allowlist_cmtat::paused(&compliance_state), 2);

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
            allowlist_cmtat::init_token(
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

            assert!(!allowlist_cmtat::deactivated(&compliance_state), 0);

            allowlist_cmtat::deactivate_contract(&admin_cap, &mut compliance_state);
            assert!(allowlist_cmtat::deactivated(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, admin_cap);
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
            allowlist_cmtat::init_token(
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
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));

            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMIN FUNCTION TESTS ==========

    #[test]
    fun test_admin_functions() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
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
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            allowlist_cmtat::set_terms(&admin_cap, &mut token, string::utf8(b"Terms"));
            allowlist_cmtat::set_information(&admin_cap, &mut token, string::utf8(b"Info"));
            allowlist_cmtat::set_token_id(&admin_cap, &mut token, string::utf8(b"ID123"));
            allowlist_cmtat::set_document_uri(&admin_cap, &mut token, string::utf8(b"https://example.com"));

            assert!(allowlist_cmtat::document_uri(&token) == string::utf8(b"https://example.com"), 0);

            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, admin_cap);
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
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                6,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);

            assert!(allowlist_cmtat::name(&token) == string::utf8(b"Allowlist Token"), 0);
            assert!(allowlist_cmtat::symbol(&token) == string::utf8(b"ALLOW"), 1);
            assert!(allowlist_cmtat::decimals(&token) == 6, 2);
            assert!(allowlist_cmtat::total_supply(&token) == 0, 3);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 4);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }
}
