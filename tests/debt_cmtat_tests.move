#[test_only]
module move_cmtat::debt_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock;
    use move_cmtat::debt_cmtat::{Self, DebtCMTAT, AdminCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    #[test]
    fun test_init_token() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Check token was created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<DebtCMTAT>(), 0);
            
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            
            assert!(debt_cmtat::name(&token) == string::utf8(b"Corporate Bond"), 1);
            assert!(debt_cmtat::symbol(&token) == string::utf8(b"BOND"), 2);
            assert!(debt_cmtat::decimals(&token) == 18, 3);
            assert!(debt_cmtat::total_supply(&token) == 1000000, 4);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_debt_management() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Set debt information
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            debt_cmtat::set_debt(&mut token, string::utf8(b"5% Annual Coupon"), ctx);
            assert!(debt_cmtat::debt(&token) == string::utf8(b"5% Annual Coupon"), 0);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_credit_events() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Set credit events
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            debt_cmtat::set_credit_events(&mut token, string::utf8(b"Coupon payment on 2024-01-01"), ctx);
            assert!(debt_cmtat::credit_events(&token) == string::utf8(b"Coupon payment on 2024-01-01"), 0);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_debt_engine() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Set debt engine
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            let engine_address = @0xDEBT;
            debt_cmtat::set_debt_engine(&mut token, engine_address, ctx);
            assert!(debt_cmtat::debt_engine(&token) == engine_address, 0);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_default() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Flag default
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            assert!(!debt_cmtat::is_default_flagged(&token), 0);
            
            debt_cmtat::flag_default(&mut token, ctx);
            assert!(debt_cmtat::is_default_flagged(&token), 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_mint_when_in_default() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Flag default and try to mint (should fail)
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            debt_cmtat::flag_default(&mut token, ctx);
            debt_cmtat::mint(&mut token, USER1, 1000, ctx); // Should fail
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            debt_cmtat::init_token(
                string::utf8(b"Corporate Bond"),
                string::utf8(b"BOND"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Create snapshot
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);
            
            debt_cmtat::schedule_snapshot(&mut token, &clock_obj, ctx);
            
            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }
}
