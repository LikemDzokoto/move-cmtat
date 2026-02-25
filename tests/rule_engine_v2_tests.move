/// RuleEngine V2 Test Suite - CMTA-Compliant Rule Orchestration Tests
#[test_only]
module move_cmtat::rule_engine_v2_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock::{Self, Clock};

    use move_cmtat::rule_engine_v2::{Self, RuleEngine};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    // ============ HELPER FUNCTIONS ============

    fun setup(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let rule_engine = rule_engine_v2::init_rule_engine_v2(ctx);
            let clock = clock::create_for_testing(ctx);
            transfer::public_share_object(rule_engine);
            clock::share_for_testing(clock);
        };
    }

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_rule_engine_v2() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let rule_engine = rule_engine_v2::init_rule_engine_v2(ctx);

            assert!(rule_engine_v2::get_request_counter(&rule_engine) == 0, 0);
            assert!(rule_engine_v2::status_none() == 0, 1);
            assert!(rule_engine_v2::status_waiting() == 1, 2);
            assert!(rule_engine_v2::status_approved() == 2, 3);
            assert!(rule_engine_v2::status_denied() == 3, 4);
            assert!(rule_engine_v2::status_executed() == 4, 5);
            assert!(rule_engine_v2::rule_whitelist() == 1, 6);
            assert!(rule_engine_v2::rule_conditional_transfer() == 2, 7);

            transfer::public_transfer(rule_engine, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_restriction_codes() {
        assert!(rule_engine_v2::restriction_code_valid() == 0, 0);
        assert!(rule_engine_v2::restriction_code_not_allowlisted() == 4, 1);
        assert!(rule_engine_v2::restriction_code_conditional_required() == 10, 2);
        assert!(rule_engine_v2::restriction_code_pending_approval() == 11, 3);
        assert!(rule_engine_v2::restriction_code_request_denied() == 12, 4);
    }

    #[test]
    fun test_message_for_restriction_code() {
        let msg = rule_engine_v2::message_for_restriction_code(0);
        assert!(msg == string::utf8(b"Transfer allowed"), 0);

        let msg = rule_engine_v2::message_for_restriction_code(10);
        assert!(msg == string::utf8(b"Transfer requires conditional approval"), 1);

        let msg = rule_engine_v2::message_for_restriction_code(11);
        assert!(msg == string::utf8(b"Transfer request pending approval"), 2);
    }

    // ============ RULE MANAGEMENT TESTS ============

    #[test]
    fun test_add_and_remove_rule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);

            assert!(!rule_engine_v2::is_rule_enabled(&rule_engine, rule_engine_v2::rule_conditional_transfer()), 0);

            rule_engine_v2::add_rule(
                &mut rule_engine,
                rule_engine_v2::rule_conditional_transfer(),
                test_scenario::ctx(scenario)
            );

            assert!(rule_engine_v2::is_rule_enabled(&rule_engine, rule_engine_v2::rule_conditional_transfer()), 1);

            rule_engine_v2::remove_rule(
                &mut rule_engine,
                rule_engine_v2::rule_conditional_transfer(),
                test_scenario::ctx(scenario)
            );

            assert!(!rule_engine_v2::is_rule_enabled(&rule_engine, rule_engine_v2::rule_conditional_transfer()), 2);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VIP MANAGEMENT TESTS ============

    #[test]
    fun test_add_and_remove_vip() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);

            assert!(!rule_engine_v2::is_vip(&rule_engine, USER1), 0);

            rule_engine_v2::add_vip(&mut rule_engine, USER1, test_scenario::ctx(scenario));

            assert!(rule_engine_v2::is_vip(&rule_engine, USER1), 1);

            rule_engine_v2::remove_vip(&mut rule_engine, USER1, test_scenario::ctx(scenario));

            assert!(!rule_engine_v2::is_vip(&rule_engine, USER1), 2);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_vip_bypasses_conditional_transfer() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);
            rule_engine_v2::add_vip(&mut rule_engine, USER1, ctx);
            rule_engine_v2::add_vip(&mut rule_engine, USER2, ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_valid(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ TRANSFER REQUEST LIFECYCLE TESTS ============

    #[test]
    fun test_create_transfer_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            let status = rule_engine_v2::get_request_status(&rule_engine, USER1, USER2, 1000);
            assert!(status == rule_engine_v2::status_waiting(), 0);

            let counter = rule_engine_v2::get_request_counter(&rule_engine);
            assert!(counter == 1, 1);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = rule_engine_v2::ERequestAlreadyExists)]
    fun test_create_duplicate_request_fails() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::create_transfer_request(&mut rule_engine, USER2, 1000, &clock, ctx);
            rule_engine_v2::create_transfer_request(&mut rule_engine, USER2, 1000, &clock, ctx);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_approve_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::approve_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            let status = rule_engine_v2::get_request_status(&rule_engine, USER1, USER2, 1000);
            assert!(status == rule_engine_v2::status_approved(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deny_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::deny_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                string::utf8(b"Compliance check failed"),
                test_scenario::ctx(scenario)
            );

            let status = rule_engine_v2::get_request_status(&rule_engine, USER1, USER2, 1000);
            assert!(status == rule_engine_v2::status_denied(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mark_executed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::approve_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::mark_executed(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            let status = rule_engine_v2::get_request_status(&rule_engine, USER1, USER2, 1000);
            assert!(status == rule_engine_v2::status_executed(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_validate_transfer_no_rules_enabled() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_valid(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_validate_transfer_not_allowlisted() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_whitelist(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                false,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_not_allowlisted(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_validate_transfer_conditional_required() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_conditional_required(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_validate_transfer_with_approved_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::approve_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_valid(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_validate_transfer_with_denied_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::deny_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                string::utf8(b"Compliance violation"),
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_request_denied(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_can_execute() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::approve_request(
                &mut rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let can_exec = rule_engine_v2::can_execute(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(can_exec == true, 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ QUERY TESTS ============

    #[test]
    fun test_get_request_status_nonexistent() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);

            let status = rule_engine_v2::get_request_status(&rule_engine, USER1, USER2, 1000);
            assert!(status == rule_engine_v2::status_none(), 0);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            rule_engine_v2::create_transfer_request(
                &mut rule_engine,
                USER2,
                1000,
                &clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);

            let (id, status, _approval_deadline, _execution_deadline) = 
                rule_engine_v2::get_request(&rule_engine, USER1, USER2, 1000);
            
            assert!(id == 0, 0);
            assert!(status == rule_engine_v2::status_waiting(), 1);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ COMPLETE WORKFLOW TESTS ============

    #[test]
    fun test_complete_conditional_transfer_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::create_transfer_request(&mut rule_engine, USER2, 1000, &clock, ctx);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::approve_request(&mut rule_engine, USER1, USER2, 1000, &clock, ctx);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let can_exec = rule_engine_v2::can_execute(&rule_engine, USER1, USER2, 1000, &clock, true, 0);
            assert!(can_exec == true, 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_vip_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_conditional_transfer(), ctx);
            rule_engine_v2::add_vip(&mut rule_engine, USER1, ctx);
            rule_engine_v2::add_vip(&mut rule_engine, USER2, ctx);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_valid(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_requests_different_values() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            rule_engine_v2::create_transfer_request(&mut rule_engine, USER2, 1000, &clock, ctx);
            rule_engine_v2::create_transfer_request(&mut rule_engine, USER2, 2000, &clock, ctx);
            rule_engine_v2::create_transfer_request(&mut rule_engine, USER3, 1500, &clock, ctx);

            let counter = rule_engine_v2::get_request_counter(&rule_engine);
            assert!(counter == 3, 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ CMTAT TRANSFER RESTRICTION INTERFACE TEST ============

    #[test]
    fun test_detect_transfer_restriction() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, USER1);
        {
            let rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);

            let _code = rule_engine_v2::detect_transfer_restriction(
                &rule_engine,
                USER1,
                USER2,
                1000,
                &clock,
                true,
                0
            );

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_status_constant_getters() {
        assert!(rule_engine_v2::status_none() == 0, 0);
        assert!(rule_engine_v2::status_waiting() == 1, 1);
        assert!(rule_engine_v2::status_approved() == 2, 2);
        assert!(rule_engine_v2::status_denied() == 3, 3);
        assert!(rule_engine_v2::status_executed() == 4, 4);
    }

    // ============ BLACKLIST TESTS ============

    #[test]
    fun test_add_remove_blacklist() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!rule_engine_v2::is_blacklisted(&rule_engine, USER1), 0);

            rule_engine_v2::add_to_blacklist(&mut rule_engine, USER1, ctx);
            assert!(rule_engine_v2::is_blacklisted(&rule_engine, USER1), 1);

            rule_engine_v2::remove_from_blacklist(&mut rule_engine, USER1, ctx);
            assert!(!rule_engine_v2::is_blacklisted(&rule_engine, USER1), 2);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_blacklist_rule_validation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Enable blacklist rule
            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_blacklist(), ctx);
            
            // Add USER1 to blacklist
            rule_engine_v2::add_to_blacklist(&mut rule_engine, USER1, ctx);

            // Validate transfer - should be blacklisted
            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                100,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_blacklisted(), 0);

            // Validate transfer from non-blacklisted - should be valid
            let code2 = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER2,
                USER3,
                100,
                &clock,
                true,
                0
            );
            assert!(code2 == rule_engine_v2::restriction_code_valid(), 1);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ SANCTION LIST TESTS ============

    #[test]
    fun test_add_remove_sanction_list() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!rule_engine_v2::is_sanctioned(&rule_engine, USER1), 0);

            rule_engine_v2::add_to_sanction_list(&mut rule_engine, USER1, ctx);
            assert!(rule_engine_v2::is_sanctioned(&rule_engine, USER1), 1);

            rule_engine_v2::remove_from_sanction_list(&mut rule_engine, USER1, ctx);
            assert!(!rule_engine_v2::is_sanctioned(&rule_engine, USER1), 2);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_sanction_list_rule_validation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Enable sanction rule
            rule_engine_v2::add_rule(&mut rule_engine, rule_engine_v2::rule_sanction_list(), ctx);
            
            // Add USER1 to sanction list
            rule_engine_v2::add_to_sanction_list(&mut rule_engine, USER1, ctx);

            // Validate transfer - should be sanctioned
            let code = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                100,
                &clock,
                true,
                0
            );
            assert!(code == rule_engine_v2::restriction_code_sanctioned(), 0);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ MAX BALANCE TESTS ============

    #[test]
    fun test_set_and_get_max_balance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(rule_engine_v2::get_max_balance(&rule_engine) == 0, 0);

            rule_engine_v2::set_max_balance(&mut rule_engine, 10000, ctx);
            assert!(rule_engine_v2::get_max_balance(&rule_engine) == 10000, 1);

            test_scenario::return_shared(rule_engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_max_balance_validation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut rule_engine = test_scenario::take_shared<RuleEngine>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Set max balance to 1000 (max transfer amount per transaction)
            rule_engine_v2::set_max_balance(&mut rule_engine, 1000, ctx);

            // Transfer 500 - should pass (500 <= 1000)
            let code1 = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                500,
                &clock,
                true,
                1000
            );
            assert!(code1 == rule_engine_v2::restriction_code_valid(), 0);

            // Transfer 1500 - should fail (1500 > 1000)
            let code2 = rule_engine_v2::validate_transfer(
                &rule_engine,
                USER1,
                USER2,
                1500,
                &clock,
                true,
                1000
            );
            assert!(code2 == rule_engine_v2::restriction_code_exceeds_max_balance(), 1);

            test_scenario::return_shared(rule_engine);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }
}
