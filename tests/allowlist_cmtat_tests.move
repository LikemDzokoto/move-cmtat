/// Allowlist CMTAT Test Suite - Comprehensive Testing
#[test_only]
module move_cmtat::allowlist_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    
    use move_cmtat::allowlist_cmtat::{Self, CMTATRegistry, AllowlistCMTATState, ComplianceState,
                                       AdminCap, FreezeCap, PauseCap, AllowlistCap, SnapshotCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    #[test]
    fun test_init_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<CMTATRegistry>(), 0);
            assert!(test_scenario::has_most_recent_shared<AllowlistCMTATState>(), 1);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 2);
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 3);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_allowlist_enable_disable() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 0);

            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);
            assert!(allowlist_cmtat::allowlist_enabled(&compliance_state), 1);

            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, false);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_address_allowlist() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);

            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true);

            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true);
            assert!(allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 0);
            assert!(!allowlist_cmtat::is_allowlisted(&compliance_state, USER2), 1);

            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, false);
            assert!(!allowlist_cmtat::is_allowlisted(&compliance_state, USER1), 2);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_freeze_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

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
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            allowlist_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 500);
            allowlist_cmtat::unfreeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 200);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_pause_unpause() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
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
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            assert!(!allowlist_cmtat::deactivated(&registry), 0);

            allowlist_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut compliance_state);
            assert!(allowlist_cmtat::deactivated(&registry), 1);

            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let allowlist_state = test_scenario::take_shared<AllowlistCMTATState>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);

            test_scenario::return_shared(allowlist_state);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_admin_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            allowlist_cmtat::set_terms(&admin_cap, &mut registry, string::utf8(b"Terms"));
            allowlist_cmtat::set_information(&admin_cap, &mut registry, string::utf8(b"Info"));
            allowlist_cmtat::set_token_id(&admin_cap, &mut registry, string::utf8(b"ID123"));
            allowlist_cmtat::set_document_uri(&admin_cap, &mut registry, string::utf8(b"https://example.com"));

            assert!(allowlist_cmtat::document_uri(&registry) == string::utf8(b"https://example.com"), 0);

            test_scenario::return_shared(registry);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_view_functions() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);

            assert!(!allowlist_cmtat::paused(&compliance_state), 0);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }
}
