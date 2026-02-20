/// Allowlist CMTAT Test Suite - Updated for Pure Native DenyList
#[test_only]
module move_cmtat::allowlist_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{DenyCapV1};
    use iota::deny_list::{Self, DenyList};

    use move_cmtat::allowlist_cmtat::{Self, ALLOWLIST_CMTAT, CMTATRegistry, AllowlistCMTATState, ComplianceState,
                                       AdminCap, AllowlistCap, SnapshotCap, MintCap, BurnCap, PauseCap, EnforcerCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // Helper to create DenyList and initialize token
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
            allowlist_cmtat::init_for_testing(ctx);
        };
    }

    // Helper to take global DenyList
    fun take_deny_list(scenario: &test_scenario::Scenario): DenyList {
        test_scenario::take_shared<DenyList>(scenario)
    }

    #[test]
    fun test_init_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

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

        setup(scenario);

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

        setup(scenario);

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
    fun test_deactivate_contract() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let mut deny_list = take_deny_list(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<ALLOWLIST_CMTAT>>(scenario);

            assert!(!allowlist_cmtat::deactivated(&registry), 0);

            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);
            assert!(allowlist_cmtat::deactivated(&registry), 1);

            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

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

        setup(scenario);

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

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let deny_list = take_deny_list(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!allowlist_cmtat::is_paused(&deny_list, ctx), 0);
            assert!(!allowlist_cmtat::allowlist_enabled(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_minter() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::grant_minter(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<MintCap>(scenario), 0);
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
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::grant_burner(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<BurnCap>(scenario), 0);
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
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::grant_pauser(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<PauseCap>(scenario), 0);
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
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::grant_enforcer(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<EnforcerCap>(scenario), 0);
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
            
            allowlist_cmtat::grant_snapshooter(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<SnapshotCap>(scenario), 0);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_grant_allowlist_manager() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::grant_allowlist_manager(&admin_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            assert!(test_scenario::has_most_recent_for_sender<AllowlistCap>(scenario), 0);
        };

        test_scenario::end(scenario_val);
    }
}
