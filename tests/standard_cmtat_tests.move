#[test_only]
module move_cmtat::standard_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::coin::{Self, TreasuryCap, CoinMetadata};
    use iota::deny_list::DenyList;
    use iota::clock;
    use iota::object;
    use iota::transfer;
    use move_cmtat::standard_cmtat::{
        Self, StandardCMTATRegistry, AdminCap, MintCap, PauseCap, FreezeCap, SnapshotCap, init_for_testing,
        create_admin_cap_for_testing, create_mint_cap_for_testing, create_pause_cap_for_testing,
        create_freeze_cap_for_testing, create_snapshot_cap_for_testing
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
            assert!(test_scenario::has_most_recent_shared<StandardCMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<DenyList>(), 1);

            // Take shared objects for inspection
            let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);

            // Verify registry is initialized correctly
            assert!(standard_cmtat::terms(&registry) == string::utf8(b""), 2);
            assert!(standard_cmtat::information(&registry) == string::utf8(b""), 3);
            assert!(standard_cmtat::token_id(&registry) == string::utf8(b""), 4);
            assert!(!standard_cmtat::deactivated(&registry), 5);

            // Check CoinMetadata is frozen (immutable)
            assert!(test_scenario::has_most_recent_immutable<CoinMetadata>(), 6);
            let metadata = test_scenario::take_immutable<CoinMetadata>(scenario);
            assert!(standard_cmtat::name(&metadata) == string::utf8(b"Standard CMTAT Token"), 7);
            assert!(standard_cmtat::symbol(&metadata) == string::utf8(b"STANDARD_CMTAT"), 8);
            assert!(standard_cmtat::decimals(&metadata) == 9, 9);
            test_scenario::return_immutable(metadata);

            // Return shared objects
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);

            // Check capabilities were transferred to deployer (ADMIN)
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 10);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 11);
            assert!(test_scenario::has_most_recent_for_sender<PauseCap>(scenario), 12);
            assert!(test_scenario::has_most_recent_for_sender<FreezeCap>(scenario), 13);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 14);
            assert!(test_scenario::has_most_recent_for_sender<TreasuryCap<StandardCMTAT>>(scenario), 15);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION TESTS ==========

    #[test]
    fun test_transfer_validation_allowed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize and mint to ADMIN
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<StandardCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        let ctx = test_scenario::ctx(scenario);
        let coins = standard_cmtat::mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 1000, ctx);
        transfer::public_transfer(coins, ADMIN);

        // Validate transfer - should be allowed
        let restriction_code = standard_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 100);
        assert!(restriction_code == icmtat::restriction_code_valid(), 0);

        let message = standard_cmtat::message_for_transfer_restriction(restriction_code);
        assert!(message == string::utf8(b"Transfer allowed"), 1);

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_when_paused() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        // Pause the contract
        standard_cmtat::pause(&pause_cap, &mut deny_list, test_scenario::ctx(scenario));

        // Validate transfer - should be restricted when paused
        let restriction_code = standard_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 100);
        assert!(restriction_code == icmtat::restriction_code_paused(), 0);

        let message = standard_cmtat::message_for_transfer_restriction(restriction_code);
        assert!(message == string::utf8(b"Contract is paused"), 1);

        // Return objects
        test_scenario::return_to_sender(scenario, pause_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_frozen_sender() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        // Freeze ADMIN
        standard_cmtat::set_address_frozen(&freeze_cap, &mut deny_list, ADMIN, true, test_scenario::ctx(scenario));

        // Validate transfer - should be restricted when sender frozen
        let restriction_code = standard_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 100);
        assert!(restriction_code == icmtat::restriction_code_frozen_sender(), 0);

        // Return objects
        test_scenario::return_to_sender(scenario, freeze_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation_insufficient_balance() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        // Try to transfer 100 tokens from ADMIN who has 0 balance
        let restriction_code = standard_cmtat::detect_transfer_restriction(&registry, &deny_list, ADMIN, USER1, 100);
        assert!(restriction_code == icmtat::restriction_code_insufficient_balance(), 0);

        // Return objects
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_restriction_code_messages() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Test message retrieval for different codes
        {
            let ctx = test_scenario::ctx(scenario);
            init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Test messages for restriction codes 0-5
            let msg0 = standard_cmtat::message_for_transfer_restriction(0);
            assert!(msg0 == string::utf8(b"Transfer allowed"), 0);

            let msg1 = standard_cmtat::message_for_transfer_restriction(1);
            assert!(msg1 == string::utf8(b"Contract is paused"), 1);

            let msg2 = standard_cmtat::message_for_transfer_restriction(2);
            assert!(msg2 == string::utf8(b"Sender address is frozen"), 2);

            let msg3 = standard_cmtat::message_for_transfer_restriction(3);
            assert!(msg3 == string::utf8(b"Recipient address is frozen"), 3);

            let msg4 = standard_cmtat::message_for_transfer_restriction(4);
            assert!(msg4 == string::utf8(b"Insufficient balance"), 4);

            let msg5 = standard_cmtat::message_for_transfer_restriction(5);
            assert!(msg5 == string::utf8(b"Unknown restriction"), 5);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER EXECUTION TESTS ==========

    #[test]
    fun test_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize and mint to ADMIN
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<StandardCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        let ctx = test_scenario::ctx(scenario);
        let coins = standard_cmtat::mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 5000, ctx);

        // Transfer to USER1
        standard_cmtat::transfer(&registry, &deny_list, coins, USER1, ctx);

        // Check USER1 received the coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<StandardCMTAT>>(scenario), 0);
            let user_coins = test_scenario::take_from_sender<Coin<StandardCMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(deny_list);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_mint() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize
        init_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);

        // Take objects
        let treasury_cap = test_scenario::take_from_sender<TreasuryCap<StandardCMTAT>>(scenario);
        let mint_cap = test_scenario::take_from_sender<MintCap>(scenario);
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let deny_list = test_scenario::take_shared<DenyList>(scenario);

        // Batch mint to multiple users
        let recipients = vector[USER1, USER2];
        let amounts = vector[1000, 2000];
        let ctx = test_scenario::ctx(scenario);
        standard_cmtat::batch_mint(&mint_cap, &mut treasury_cap, &registry, &deny_list, recipients, amounts, ctx);

        // Check total supply
        assert!(coin::total_supply(&treasury_cap) == 3000, 0);

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<StandardCMTAT>>(scenario), 1);
            let user_coins = test_scenario::take_from_sender<Coin<StandardCMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 1000, 2);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        // Check USER2 received coins
        test_scenario::next_tx(scenario, USER2);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<StandardCMTAT>>(scenario), 3);
            let user_coins = test_scenario::take_from_sender<Coin<StandardCMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 2000, 4);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        // Return objects
        test_scenario::return_to_sender(scenario, treasury_cap);
        test_scenario::return_to_sender(scenario, mint_cap);
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
        let registry = test_scenario::take_shared<StandardCMTATRegistry>(scenario);
        let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
        let ctx = test_scenario::ctx(scenario);

        // Create snapshot
        standard_cmtat::schedule_snapshot(&snapshot_cap, &mut registry, &clock_obj, ctx);

        // Return objects
        clock::destroy_for_testing(clock_obj);
        test_scenario::return_to_sender(scenario, snapshot_cap);
        test_scenario::return_shared(registry);

        test_scenario::end(scenario_val);
    }
}