/// Debt CMTAT Test Suite - Updated for Pure Native DenyList
#[test_only]
module move_cmtat::debt_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    use iota::coin::{DenyCapV1};
    use iota::deny_list::{Self, DenyList};

    use move_cmtat::debt_cmtat::{Self, DEBT_CMTAT, CMTATRegistry, DebtCMTATState, ComplianceState,
                                   AdminCap, DebtCap, SnapshotCap};

    const ADMIN: address = @0xAD;
    const DEBT_ENGINE: address = @0xDE;

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
            debt_cmtat::init_for_testing(ctx);
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
            assert!(test_scenario::has_most_recent_shared<DebtCMTATState>(), 1);
            assert!(test_scenario::has_most_recent_shared<ComplianceState>(), 2);
            assert!(test_scenario::has_most_recent_for_sender<AdminCap>(scenario), 3);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_debt() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
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
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            debt_cmtat::set_credit_events(
                &debt_cap,
                &mut compliance_state,
                false,  // flag_default
                false,  // flag_redeemed
                false,  // flag_matured
                string::utf8(b"AAA"),  // rating
                0,      // principal_distributed
                0,      // next_coupon_date
            );

            let _events = debt_cmtat::credit_events(&compliance_state);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_debt_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 0);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::flag_default(&debt_cap, &mut compliance_state, ctx);
            assert!(debt_cmtat::is_default_flagged(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
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
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<DEBT_CMTAT>>(scenario);

            assert!(!debt_cmtat::deactivated(&registry), 0);

            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);
            assert!(debt_cmtat::deactivated(&registry), 1);

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
            let debt_state = test_scenario::take_shared<DebtCMTATState>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<SnapshotCap>(scenario);

            test_scenario::return_shared(debt_state);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_comprehensive_debt_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            debt_cmtat::set_debt(&debt_cap, &mut compliance_state,
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"));

            debt_cmtat::set_credit_events(
                &debt_cap,
                &mut compliance_state,
                false,
                false,
                false,
                string::utf8(b"AAA"),
                0,
                0,
            );

            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            assert!(debt_cmtat::debt(&compliance_state) ==
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"), 0);
            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 2);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 3);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
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

            // Test native DenyList compliance views
            assert!(!debt_cmtat::is_paused(&deny_list, ctx), 0);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }
}
