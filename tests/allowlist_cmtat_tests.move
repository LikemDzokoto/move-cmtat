#[test_only]
module move_cmtat::allowlist_cmtat_tests {
    use std::string;
    use std::vector;
    use iota::test_scenario::{Self, Scenario};
    use iota::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::clock;
    use iota::event;
    use iota::object;
    use iota::transfer;
    use move_cmtat::allowlist_cmtat::{Self, AllowlistCMTATRegistry, AllowlistCMTAT, ComplianceState, AdminCap, MintCap, FreezeCap, AllowlistCap, SnapshotCap};
    use move_cmtat::icmtat;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // ========== INIT TOKEN TEST ==========
    // IOTA Native: Tests initialization with shared objects and capabilities
    // Follows native patterns: shared objects, capabilities, no balance_of

    #[test]
    fun test_init_token() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token using existing pattern (until contracts are refactored)
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0, // No initial supply for native pattern
                ADMIN,
                ctx
            );
        };

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            // Check shared objects exist (AllowlistCMTAT and ComplianceState)
            assert!(test_scenario::has_most_recent_shared<AllowlistCMTAT>(), 0);

            // Take objects for inspection
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);

            // Verify token metadata (no balance_of - balances are in Coin objects)
            assert!(allowlist_cmtat::name(&token) == string::utf8(b"Allowlist Token"), 1);
            assert!(allowlist_cmtat::symbol(&token) == string::utf8(b"ALLOW"), 2);
            assert!(allowlist_cmtat::decimals(&token) == 18, 3);
            assert!(allowlist_cmtat::total_supply(&token) == 0, 4); // No initial supply

            // Verify compliance state
            assert!(!allowlist_cmtat::paused(&compliance_state), 5);
            assert!(!allowlist_cmtat::deactivated(&compliance_state), 6);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 7);

            // Return objects
            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ALLOWLIST ENABLE/DISABLE TEST ==========
    // IOTA Native: Tests allowlist toggle with capabilities

    #[test]
    fun test_allowlist_enable_disable() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Get capabilities and enable allowlist
        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<allowlist_cmtat::AllowlistCap>(scenario);

            // Enable allowlist
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);
            assert!(allowlist_cmtat::allowlist_enabled(&compliance_state), 0);

            // Disable allowlist
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, false);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SET ADDRESS ALLOWLIST TEST ==========
    // IOTA Native: Tests adding/removing addresses from allowlist

    #[test]
    fun test_set_address_allowlist() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and enable allowlist
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<allowlist_cmtat::AllowlistCap>(scenario);

            // Enable allowlist first
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            // Add USER1 to allowlist
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true);
            assert!(allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 0);

            // Remove USER1 from allowlist
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, false);
            assert!(!allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== PARTIAL FREEZE TEST ==========
    // IOTA Native: Tests partial token freezing (no balance_of calls)

    #[test]
    fun test_partial_freeze() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and mint to USER1
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<allowlist_cmtat::MintCap>(scenario);
            let freeze_cap = test_scenario::take_from_sender<allowlist_cmtat::FreezeCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Mint 1000 tokens to USER1
            allowlist_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 1000, ctx);

            // Freeze 300 tokens
            allowlist_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 300);

            // Active balance should be 700 (total - frozen)
            // Note: In native implementation, this would be calculated from Coin objects
            assert!(allowlist_cmtat::get_active_balance_of(&token, &compliance_state, USER1) == 700, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== GET ACTIVE BALANCE TEST ==========
    // IOTA Native: Tests calculation of active balance (total - frozen)

    #[test]
    fun test_get_active_balance() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and setup balances
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);
            let mint_cap = test_scenario::take_from_sender<allowlist_cmtat::MintCap>(scenario);
            let freeze_cap = test_scenario::take_from_sender<allowlist_cmtat::FreezeCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Mint tokens and freeze some
            allowlist_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 1000, ctx);
            allowlist_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 250);

            // Verify active balance calculation (no balance_of calls)
            assert!(allowlist_cmtat::get_active_balance_of(&token, &compliance_state, USER1) == 750, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ALLOWLIST TRANSFER VALIDATION TEST ==========
    // IOTA Native: Tests transfer blocked when address not allowlisted

    #[test]
    #[expected_failure(abort_code = 2003)] // ETransferRestricted
    fun test_allowlist_transfer_validation() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token, enable allowlist, mint to ADMIN
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<allowlist_cmtat::ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<allowlist_cmtat::AllowlistCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Enable allowlist but don't add USER1
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            // Try to transfer to USER1 - should fail due to allowlist restriction
            // Note: Transfer function would need to be updated for native patterns
            let coin = coin::zero<allowlist_cmtat::base::CMTAT>(ctx); // Placeholder
            allowlist_cmtat::transfer(&compliance_state, coin, USER1, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SNAPSHOT TEST ==========
    // IOTA Native: Tests snapshot creation

    #[test]
    fun test_snapshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<allowlist_cmtat::SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            // Create snapshot
            allowlist_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }
}</content>
<parameter name="filePath">/mnt/c/Users/Likem/Documents/move-cmtat/tests/allowlist_cmtat_tests.move