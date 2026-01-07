/// Debt CMTAT Test Suite - Comprehensive Testing for Debt Securities
#[test_only]
module move_cmtat::debt_cmtat_tests_new {
    use std::string;
    use iota::test_scenario::{Self};
    
    use move_cmtat::debt_cmtat::{Self, CMTATRegistry, DebtCMTATState, ComplianceState,
                                   AdminCap, PauseCap, DebtCap, FreezeCap, SnapshotCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const DEBT_ENGINE: address = @0xDE;

    #[test]
    fun test_init_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

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

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

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

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            let events = string::utf8(b"Coupon payment on 2024-06-15: $50,000");
            debt_cmtat::set_credit_events(&debt_cap, &mut compliance_state, events);

            assert!(debt_cmtat::credit_events(&compliance_state) == events, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_debt_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

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

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

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
    fun test_pause_unpause() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let pause_cap = test_scenario::take_from_sender<PauseCap>(scenario);

            assert!(!debt_cmtat::paused(&compliance_state), 0);

            debt_cmtat::pause(&pause_cap, &mut compliance_state);
            assert!(debt_cmtat::paused(&compliance_state), 1);

            debt_cmtat::unpause(&pause_cap, &mut compliance_state);
            assert!(!debt_cmtat::paused(&compliance_state), 2);

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
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut registry = test_scenario::take_shared<CMTATRegistry>(scenario);
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            assert!(!debt_cmtat::deactivated(&registry), 0);

            debt_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut compliance_state);
            assert!(debt_cmtat::deactivated(&registry), 1);

            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_freeze_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            assert!(!debt_cmtat::is_frozen(&compliance_state, USER1), 0);

            debt_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, true);
            assert!(debt_cmtat::is_frozen(&compliance_state, USER1), 1);

            debt_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, USER1, false);
            assert!(!debt_cmtat::is_frozen(&compliance_state, USER1), 2);

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
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<FreezeCap>(scenario);

            debt_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 500);
            debt_cmtat::unfreeze_partial_tokens(&freeze_cap, &mut compliance_state, USER1, 200);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

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

        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<DebtCap>(scenario);

            debt_cmtat::set_debt(&debt_cap, &mut compliance_state, 
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"));
            
            debt_cmtat::set_credit_events(&debt_cap, &mut compliance_state,
                string::utf8(b"2024-06-30: Coupon payment $55,000"));
            
            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            assert!(debt_cmtat::debt(&compliance_state) == 
                string::utf8(b"5.5% Annual Coupon, Maturity 2030-12-31"), 0);
            assert!(debt_cmtat::credit_events(&compliance_state) == 
                string::utf8(b"2024-06-30: Coupon payment $55,000"), 1);
            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 2);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 3);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }
}
