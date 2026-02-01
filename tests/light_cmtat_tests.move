/// Light CMTAT Test Suite - IOTA Native Regulated Currency
/// Tests initialization, minting, burning, transfers, freeze/pause via DenyList
#[test_only]
module move_cmtat::light_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::transfer::public_transfer;

    use move_cmtat::light_cmtat::{Self, LIGHT_CMTAT, LightCMTATRegistry, AdminCap, MinterCap, PauserCap, EnforcerCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Helper to take global DenyList
    fun take_deny_list(scenario: &test_scenario::Scenario): DenyList {
        test_scenario::take_shared<DenyList>(scenario)
    }

    // Helper to initialize for testing
    fun setup(scenario: &mut test_scenario::Scenario) {
        // Create DenyList as system address @0x0
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            deny_list::create_for_test(ctx);
        };
        // Initialize token as ADMIN
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_for_testing(ctx);
        };
    }

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Verify objects created
        test_scenario::next_tx(scenario, ADMIN);
        {
            // Check shared objects
            assert!(test_scenario::has_most_recent_shared<LightCMTATRegistry>(), 0);

            // Check immutable metadata
            assert!(test_scenario::has_most_recent_immutable<CoinMetadata<LIGHT_CMTAT>>(), 1);

            // Check capabilities
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<MinterCap>(scenario), 4);
            assert!(test_scenario::has_most_recent_for_sender<PauserCap>(scenario), 5);
            assert!(test_scenario::has_most_recent_for_sender<EnforcerCap>(scenario), 6);
            assert!(test_scenario::has_most_recent_for_sender<TreasuryCap<LIGHT_CMTAT>>(scenario), 7);
            assert!(test_scenario::has_most_recent_for_sender<DenyCapV1<LIGHT_CMTAT>>(scenario), 8);
        };

        test_scenario::end(scenario_val);
    }

    // ========== VIEW FUNCTION TESTS ==========

    #[test]
    fun test_view_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let metadata = test_scenario::take_immutable<CoinMetadata<LIGHT_CMTAT>>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);

            // Test metadata
            assert!(light_cmtat::name(&metadata) == string::utf8(b"Light CMTAT Token"), 0);
            assert!(light_cmtat::symbol(&metadata) == string::utf8(b"LCMTAT"), 1);
            assert!(light_cmtat::decimals(&metadata) == 9, 2);

            // Test registry
            assert!(light_cmtat::terms(&registry) == string::utf8(b""), 3);
            assert!(light_cmtat::information(&registry) == string::utf8(b""), 4);
            assert!(light_cmtat::token_id(&registry) == string::utf8(b""), 5);
            assert!(!light_cmtat::deactivated(&registry), 6);

            // Test supply
            assert!(light_cmtat::total_supply(&treasury_cap) == 0, 7);

            test_scenario::return_immutable(metadata);
            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== MINTING TESTS ==========

    #[test]
    fun test_mint() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, USER1, 5000, ctx);

            assert!(coin::value(&coins) == 5000, 0);
            assert!(light_cmtat::total_supply(&treasury_cap) == 5000, 1);

             public_transfer(coins, USER1);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        // Verify USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<LIGHT_CMTAT>>(scenario), 0);
            let user_coins = test_scenario::take_from_sender<Coin<LIGHT_CMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint_and_transfer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            light_cmtat::mint_and_transfer(&minter_cap, &mut treasury_cap, &registry, &deny_list, USER1, 3000, ctx);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        // Verify USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            let user_coins = test_scenario::take_from_sender<Coin<LIGHT_CMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 3000, 0);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_mint() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let recipients = vector[USER1, USER2];
            let amounts = vector[1000, 2000];

            let ctx = test_scenario::ctx(scenario);
            light_cmtat::batch_mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, recipients, amounts, ctx);

            assert!(light_cmtat::total_supply(&treasury_cap) == 3000, 0);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_when_paused() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let pauser_cap = test_scenario::take_from_sender<PauserCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            // Pause
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::pause(&pauser_cap, &mut deny_list, &mut deny_cap, &registry, ctx);

            // Try to mint - should fail
            let coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, USER1, 1000, ctx);
             public_transfer(coins, USER1);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_to_sender(scenario, pauser_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_to_frozen_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let enforcer_cap = test_scenario::take_from_sender<EnforcerCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            // Freeze USER1
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::set_address_frozen(&enforcer_cap, &mut deny_list, &mut deny_cap, USER1, true, ctx);

            // Try to mint to frozen address - should fail
            let coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, USER1, 1000, ctx);
             public_transfer(coins, USER1);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_to_sender(scenario, enforcer_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== BURNING TESTS ==========

    #[test]
    fun test_burn() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 5000, ctx);

            assert!(light_cmtat::total_supply(&treasury_cap) == 5000, 0);

            // Burn
            light_cmtat::burn_entry(&mut treasury_cap, coins, ctx);
            assert!(light_cmtat::total_supply(&treasury_cap) == 0, 1);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_burn_and_mint() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            let burn_coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 3000, ctx);

            assert!(light_cmtat::total_supply(&treasury_cap) == 3000, 0);

            // Burn and mint
            light_cmtat::burn_and_mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, burn_coins, USER1, 1500, ctx);
            assert!(light_cmtat::total_supply(&treasury_cap) == 1500, 1);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER TESTS ==========

    #[test]
    fun test_transfer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let minter_cap = test_scenario::take_from_sender<MinterCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = take_deny_list(scenario);

            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&minter_cap, &mut treasury_cap, &registry, &deny_list, ADMIN, 5000, ctx);

            // Transfer to USER1
            light_cmtat::transfer(&registry, &deny_list, coins, USER1, ctx);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, minter_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        // Verify USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            let user_coins = test_scenario::take_from_sender<Coin<LIGHT_CMTAT>>(scenario);
            assert!(coin::value(&user_coins) == 5000, 0);
            test_scenario::return_to_sender(scenario, user_coins);
        };

        test_scenario::end(scenario_val);
    }

    // ========== FREEZE TESTS ==========

    #[test]
    fun test_freeze_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let enforcer_cap = test_scenario::take_from_sender<EnforcerCap>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            let ctx = test_scenario::ctx(scenario);

            // Freeze USER1
            light_cmtat::set_address_frozen(&enforcer_cap, &mut deny_list, &mut deny_cap, USER1, true, ctx);
            assert!(light_cmtat::is_frozen(&deny_list, USER1, ctx), 0);

            // Unfreeze USER1
            light_cmtat::set_address_frozen(&enforcer_cap, &mut deny_list, &mut deny_cap, USER1, false, ctx);
            assert!(!light_cmtat::is_frozen(&deny_list, USER1, ctx), 1);

            test_scenario::return_to_sender(scenario, enforcer_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_freeze() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let enforcer_cap = test_scenario::take_from_sender<EnforcerCap>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            let accounts = vector[USER1, USER2];
            let statuses = vector[true, true];

            let ctx = test_scenario::ctx(scenario);
            light_cmtat::batch_set_address_frozen(&enforcer_cap, &mut deny_list, &mut deny_cap, accounts, statuses, ctx);

            assert!(light_cmtat::is_frozen(&deny_list, USER1, ctx), 0);
            assert!(light_cmtat::is_frozen(&deny_list, USER2, ctx), 1);

            test_scenario::return_to_sender(scenario, enforcer_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== PAUSE TESTS ==========

    #[test]
    fun test_pause_unpause() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let pauser_cap = test_scenario::take_from_sender<PauserCap>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            let ctx = test_scenario::ctx(scenario);

            assert!(!light_cmtat::is_paused(&deny_list, ctx), 0);

            // Pause
            light_cmtat::pause(&pauser_cap, &mut deny_list, &mut deny_cap, &registry, ctx);
            assert!(light_cmtat::is_paused(&deny_list, ctx), 1);

            // Unpause
            light_cmtat::unpause(&pauser_cap, &mut deny_list, &mut deny_cap, &registry, ctx);
            assert!(!light_cmtat::is_paused(&deny_list, ctx), 2);

            test_scenario::return_to_sender(scenario, pauser_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== DEACTIVATION TESTS ==========

    #[test]
    fun test_deactivate_contract() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);

            assert!(!light_cmtat::deactivated(&registry), 0);

            let ctx = test_scenario::ctx(scenario);
            light_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);

            assert!(light_cmtat::deactivated(&registry), 1);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ========== CAPABILITY GRANTING TESTS ==========

    #[test]
    fun test_grant_minter() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            light_cmtat::grant_minter(&admin_cap, USER1, ctx);

            test_scenario::return_to_sender(scenario, admin_cap);
        };

        // Verify USER1 received capability
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<MinterCap>(scenario), 0);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMINISTRATIVE TESTS ==========

    #[test]
    fun test_admin_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);

            light_cmtat::set_terms(&admin_cap, &mut registry, string::utf8(b"New Terms"));
            light_cmtat::set_information(&admin_cap, &mut registry, string::utf8(b"New Info"));
            light_cmtat::set_token_id(&admin_cap, &mut registry, string::utf8(b"TOKEN123"));

            assert!(light_cmtat::terms(&registry) == string::utf8(b"New Terms"), 0);
            assert!(light_cmtat::information(&registry) == string::utf8(b"New Info"), 1);
            assert!(light_cmtat::token_id(&registry) == string::utf8(b"TOKEN123"), 2);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }
}
