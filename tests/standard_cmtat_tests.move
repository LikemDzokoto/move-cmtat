/// Standard CMTAT Test Suite - Updated for Pure Native DenyList
/// Tests initialization, minting, burning, transfers, freeze, pause, and snapshots
#[test_only]
#[allow(unused_use, unused_mut_ref, duplicate_alias)]
module move_cmtat::standard_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::clock::{Self, Clock};
    use iota::transfer;

    use move_cmtat::standard_cmtat::{Self, STANDARD_CMTAT, CMTATRegistry, StandardCMTATState,
                                      AdminCap, MintCap, BurnCap, PauseCap, SnapshotCap, EnforcerCap};
    use move_cmtat::rule_engine_v2;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;

    // Helper to take global DenyList
    fun take_deny_list(scenario: &test_scenario::Scenario): DenyList {
        test_scenario::take_shared<DenyList>(scenario)
    }

    // Helper to take Clock
    fun take_clock(scenario: &test_scenario::Scenario): Clock {
        test_scenario::take_shared<Clock>(scenario)
    }

    // Helper to initialize for testing
    fun setup(scenario: &mut test_scenario::Scenario) {
        // Create DenyList as system address @0x0
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            deny_list::create_for_test(ctx);
        };
        // Create Clock as system address @0x0
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);
            clock::share_for_testing(clock);
        };
        // Initialize token as ADMIN
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_for_testing(ctx);
        };
    }

    // ========== INITIALIZATION TESTS ==========

    #[test]
    fun test_init() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<CMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<StandardCMTATState>(), 1);

            // Verify capabilities were transferred to admin
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 3);
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 4);
            assert!(test_scenario::has_most_recent_for_sender<BurnCap>(scenario), 5);
            assert!(test_scenario::has_most_recent_for_sender<PauseCap>(scenario), 7);
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 8);
            assert!(test_scenario::has_most_recent_for_sender<EnforcerCap>(scenario), 9);
            assert!(test_scenario::has_most_recent_for_sender<TreasuryCap<STANDARD_CMTAT>>(scenario), 10);
            assert!(test_scenario::has_most_recent_for_sender<DenyCapV1<STANDARD_CMTAT>>(scenario), 11);

            // Check immutable metadata
            assert!(test_scenario::has_most_recent_immutable<CoinMetadata<STANDARD_CMTAT>>(), 12);
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
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let metadata = test_scenario::take_immutable<CoinMetadata<STANDARD_CMTAT>>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);
            let deny_list = take_deny_list(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Test metadata (native CoinMetadata)
            assert!(standard_cmtat::name(&metadata) == string::utf8(b"Standard CMTAT Token"), 0);
            assert!(standard_cmtat::symbol(&metadata) == string::utf8(b"STCMTAT"), 1);
            assert!(standard_cmtat::decimals(&metadata) == 9, 2);
            assert!(standard_cmtat::total_supply(&treasury_cap) == 0, 3);

            // Test registry
            assert!(standard_cmtat::terms(&registry) == string::utf8(b""), 4);
            assert!(!standard_cmtat::deactivated(&registry), 5);

            // Test native DenyList compliance
            assert!(!standard_cmtat::is_paused(&deny_list, ctx), 6);
            assert!(!standard_cmtat::is_frozen(&deny_list, USER1, ctx), 7);

            test_scenario::return_immutable(metadata);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
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
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);
            let deny_list = take_deny_list(scenario);
            let clock = take_clock(scenario);

            // Add USER1 as VIP (whitelist) to pass RuleEngine validation
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::add_vip(&admin_cap, &mut state, USER1, ctx);

            // Now mint should work
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint_and_transfer(&mut treasury_cap, &registry, &mut state, &deny_list, &clock, USER1, 5000, ctx);

            // Check total supply increased
            assert!(standard_cmtat::total_supply(&treasury_cap) == 5000, 0);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(clock);
            test_scenario::return_to_sender(scenario, treasury_cap);
        };

        // Check USER1 received coins
        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<Coin<STANDARD_CMTAT>>(scenario), 0);
            let coins = test_scenario::take_from_sender<Coin<STANDARD_CMTAT>>(scenario);
            assert!(coin::value(&coins) == 5000, 1);
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::end(scenario_val);
    }

    // ========== ADMINISTRATIVE TESTS ==========

    #[test]
    fun test_set_metadata() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            standard_cmtat::set_terms(&admin_cap, &mut registry, string::utf8(b"New Terms"), ctx);
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::set_information(&admin_cap, &mut registry, string::utf8(b"New Info"), ctx);
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::set_token_id(&admin_cap, &mut registry, string::utf8(b"TOKEN123"), ctx);
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::set_document_uri(&admin_cap, &mut registry, string::utf8(b"https://example.com"), ctx);

            assert!(standard_cmtat::document_uri(&registry) == string::utf8(b"https://example.com"), 0);
            assert!(standard_cmtat::terms(&registry) == string::utf8(b"New Terms"), 1);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== RULE ENGINE TESTS ==========

    #[test]
    fun test_rule_engine_active_by_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<StandardCMTATState>(scenario);

            // RuleEngine should be active by default after init
            assert!(standard_cmtat::rule_engine_active(&state), 0);

            // Whitelist rule should be enabled by default
            assert!(standard_cmtat::is_rule_enabled(&state, rule_engine_v2::rule_whitelist()), 1);

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_remove_vip() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // USER1 is not VIP initially
            assert!(!standard_cmtat::is_vip(&state, USER1), 0);

            // Add USER1 as VIP
            standard_cmtat::add_vip(&admin_cap, &mut state, USER1, ctx);

            // Now USER1 should be VIP
            assert!(standard_cmtat::is_vip(&state, USER1), 1);

            // Remove USER1 from VIP
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::remove_vip(&admin_cap, &mut state, USER1, ctx);

            // USER1 should no longer be VIP
            assert!(!standard_cmtat::is_vip(&state, USER1), 2);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_restore_rule_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);

            // RuleEngine should be active initially
            assert!(standard_cmtat::rule_engine_active(&state), 0);

            // Remove RuleEngine
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::remove_rule_engine(&admin_cap, &mut state, ctx);

            // RuleEngine should now be inactive
            assert!(!standard_cmtat::rule_engine_active(&state), 1);

            // Restore RuleEngine
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::restore_rule_engine(&admin_cap, &mut state, ctx);

            // RuleEngine should be active again
            assert!(standard_cmtat::rule_engine_active(&state), 2);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_remove_rule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);

            // Whitelist should be enabled by default
            assert!(standard_cmtat::is_rule_enabled(&state, rule_engine_v2::rule_whitelist()), 0);

            // Remove whitelist rule
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::remove_rule(&admin_cap, &mut state, rule_engine_v2::rule_whitelist(), ctx);

            // Whitelist should be disabled
            assert!(!standard_cmtat::is_rule_enabled(&state, rule_engine_v2::rule_whitelist()), 1);

            // Add whitelist rule back
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::add_rule(&admin_cap, &mut state, rule_engine_v2::rule_whitelist(), ctx);

            // Whitelist should be enabled again
            assert!(standard_cmtat::is_rule_enabled(&state, rule_engine_v2::rule_whitelist()), 2);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_schedule_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);
            let deny_list = take_deny_list(scenario);
            let clock = take_clock(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::mint_and_transfer(
                &mut treasury_cap,
                &registry,
                &mut state,
                &deny_list,
                &clock,
                ADMIN,
                1000,
                ctx
            );

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, snapshot_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<STANDARD_CMTAT>>(scenario);
            let mut state = test_scenario::take_shared<StandardCMTATState>(scenario);
            let clock = take_clock(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::schedule_snapshot(&snapshot_cap, &mut state, &treasury_cap, &clock, ctx);

            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_to_sender(scenario, snapshot_cap);
            test_scenario::return_shared(state);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }
}
