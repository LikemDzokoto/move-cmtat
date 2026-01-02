#[test_only]
module move_cmtat::allowlist_cmtat_tests {
    use std::string;
    use std::vector;
    use iota::test_scenario::{Self, Scenario};
    use iota::coin::{Self, TreasuryCap, CoinMetadata};
    use iota::deny_list::DenyList;
    use iota::clock;
    use iota::object;
    use iota::transfer;
    use move_cmtat::allowlist_cmtat::{
        Self, AllowlistCMTATRegistry, AdminCap, MintCap, FreezeCap, AllowlistCap, SnapshotCap, init_for_testing,
        create_admin_cap_for_testing, create_mint_cap_for_testing, create_freeze_cap_for_testing,
        create_allowlist_cap_for_testing, create_snapshot_cap_for_testing
    };
    use move_cmtat::icmtat;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init_token() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token using one-time witness
        {
            let ctx = test_scenario::ctx(scenario);
            init_for_testing(ctx);
        };

        // Verify objects created and shared
        test_scenario::next_tx(scenario, ADMIN);
        {
            // Check shared objects exist
            assert!(test_scenario::has_most_recent_shared<AllowlistCMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<DenyList>(), 1);

            // Take shared objects for inspection
            let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);

            // Verify registry is initialized correctly
            assert!(allowlist_cmtat::terms(&registry) == string::utf8(b""), 2);
            assert!(allowlist_cmtat::information(&registry) == string::utf8(b""), 3);
            assert!(allowlist_cmtat::token_id(&registry) == string::utf8(b""), 4);
            assert!(!allowlist_cmtat::deactivated(&registry), 5);
            assert!(!allowlist_cmtat::allowlist_enabled(&registry), 6);

            // Check CoinMetadata is frozen (immutable)
            assert!(test_scenario::has_most_recent_immutable<CoinMetadata>(), 7);
            let metadata = test_scenario::take_immutable<CoinMetadata>(scenario);
            assert!(allowlist_cmtat::name(&metadata) == string::utf8(b"Allowlist CMTAT Token"), 8);
            assert!(allowlist_cmtat::symbol(&metadata) == string::utf8(b"ALLOWLIST_CMTAT"), 9);
            assert!(allowlist_cmtat::decimals(&metadata) == 9, 10);
            test_scenario::return_immutable(metadata);

            // Return shared objects
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);

            // Check capabilities were transferred to deployer (ADMIN)
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 11);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 12);
            assert!(test_scenario::has_most_recent_for_sender<FreezeCap>(scenario), 13);
            assert!(test_scenario::has_most_recent_for_sender<AllowlistCap>(scenario), 14);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 15);
            assert!(test_scenario::has_most_recent_for_sender<TreasuryCap<AllowlistCMTAT>>(scenario), 16);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ALLOWLIST MANAGEMENT TESTS ==========

    #[test]
    fun test_allowlist_enable_disable() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        // Take required objects
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);

        // Enable allowlist
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, true);
        assert!(allowlist_cmtat::allowlist_enabled(&registry), 0);

        // Disable allowlist
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, false);
        assert!(!allowlist_cmtat::allowlist_enabled(&registry), 1);

        // Return objects
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(registry);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_address_allowlist() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        // Take required objects
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);

        // Enable allowlist first
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, true);

        // Add USER1 to allowlist
        allowlist_cmtat::set_address_allowlist(&admin_cap, &mut registry, USER1, true);
        assert!(allowlist_cmtat::is_allowlisted(&registry, USER1), 0);
        assert!(!allowlist_cmtat::is_allowlisted(&registry, USER2), 1);

        // Remove USER1 from allowlist
        allowlist_cmtat::set_address_allowlist(&admin_cap, &mut registry, USER1, false);
        assert!(!allowlist_cmtat::is_allowlisted(&registry, USER1), 2);

        // Return objects
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(registry);

        test_scenario::end(scenario_val);
    }

    // ========== FREEZE AND BALANCE TESTS ==========

    #[test]
    fun test_partial_freeze() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize and mint to USER1
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<AllowlistCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        let ctx = test_scenario::ctx(scenario);

        // Mint 1000 tokens to USER1
        let coins = allowlist_cmtat::mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, USER1, 1000, ctx);
        transfer::public_transfer(coins, USER1);

        // Freeze 300 tokens
        allowlist_cmtat::freeze_partial_tokens(&freeze_cap, &registry, &mut deny_list, USER1, 300, ctx);

        // Active balance should be 700 (total - frozen)
        // Note: Active balance calculation requires knowing total balance, which is in Coin objects
        // In real implementation, this would be calculated from user's Coin balance minus frozen amount
        assert!(allowlist_cmtat::frozen_balance(&deny_list, USER1) == 300, 0);

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
        test_scenario::return_to_sender(scenario, freeze_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_with_allowlist() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize and enable allowlist
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        // Enable allowlist but don't add USER1
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, true);

        // Validate transfer - should be restricted when recipient not allowlisted
        let restriction_code = allowlist_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 100);
        assert!(restriction_code == icmtat::restriction_code_allowlist(), 0);

        // Add USER1 to allowlist
        allowlist_cmtat::set_address_allowlist(&admin_cap, &mut registry, USER1, true);

        // Now transfer should be allowed (assuming other conditions met)
        let restriction_code = allowlist_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 0); // 0 amount for balance check
        assert!(restriction_code == icmtat::restriction_code_valid(), 1);

        // Return objects
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER EXECUTION TESTS ==========

    #[test]
    fun test_transfer_when_allowlisted() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize, enable allowlist, and add USER1
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<AllowlistCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        let ctx = test_scenario::ctx(scenario);

        // Enable allowlist and add USER1
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, true);
        allowlist_cmtat::set_address_allowlist(&admin_cap, &mut registry, USER1, true);

        // Mint tokens to ADMIN
        let coins = allowlist_cmtat::mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 5000, ctx);

        // Transfer to USER1 - should succeed since allowlisted
        allowlist_cmtat::transfer(&registry, &deny_list, coins, USER1, ctx);

        // Check USER1 received the coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<AllowlistCMTAT>>(scenario), 0);
            let user_coins = test_scenario::take_from_sender<Coin<AllowlistCMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_transfer_when_not_allowlisted() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize and enable allowlist but don't add USER1
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<AllowlistCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        let ctx = test_scenario::ctx(scenario);

        // Enable allowlist but don't add USER1
        allowlist_cmtat::enable_allowlist(&admin_cap, &mut registry, true);

        // Mint tokens to ADMIN
        let coins = allowlist_cmtat::mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 5000, ctx);

        // Try to transfer to USER1 - should fail since not allowlisted
        allowlist_cmtat::transfer(&registry, &deny_list, coins, USER1, ctx);

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        // Take required objects
        let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);
        let registry = test_scenario::take_shared<AllowlistCMTATRegistry>(scenario);
        let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
        let ctx = test_scenario::ctx(scenario);

        // Create snapshot
        allowlist_cmtat::schedule_snapshot(&snapshot_cap, &mut registry, &clock_obj, ctx);

        // Return objects
        clock::destroy_for_testing(clock_obj);
        test_scenario::return_to_sender(scenario, snapshot_cap);
        test_scenario::return_shared(registry);

        test_scenario::end(scenario_val);
    }
}