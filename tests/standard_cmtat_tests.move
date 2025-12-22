#[test_only]
module move_cmtat::standard_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock;
    use move_cmtat::standard_cmtat::{Self, StandardCMTAT, AdminCap};
    use move_cmtat::icmtat;

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
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Check token was created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<StandardCMTAT>(), 0);
            
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            
            assert!(standard_cmtat::name(&token) == string::utf8(b"Standard Token"), 1);
            assert!(standard_cmtat::symbol(&token) == string::utf8(b"STD"), 2);
            assert!(standard_cmtat::decimals(&token) == 18, 3);
            assert!(standard_cmtat::total_supply(&token) == 1000000, 4);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_validation() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Test transfer restriction detection
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            
            // Normal transfer should be valid
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(code == icmtat::restriction_code_valid(), 0);
            
            // Get message for valid transfer
            let msg = standard_cmtat::message_for_transfer_restriction(code);
            assert!(msg == string::utf8(b"Transfer allowed"), 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_restriction_when_paused() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Pause and check restriction
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            standard_cmtat::pause(&mut token, ctx);
            
            // Transfer should be restricted when paused
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(code == icmtat::restriction_code_paused(), 0);
            
            // Get message for paused restriction
            let msg = standard_cmtat::message_for_transfer_restriction(code);
            assert!(msg == string::utf8(b"Contract is paused"), 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_transfer_restriction_when_frozen() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Freeze sender and check restriction
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            standard_cmtat::set_address_frozen(&mut token, ADMIN, true, ctx);
            
            // Transfer should be restricted when sender is frozen
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(code == icmtat::restriction_code_frozen_sender(), 0);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_successful_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Transfer tokens
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            standard_cmtat::transfer(&mut token, USER1, 500, ctx);
            
            assert!(standard_cmtat::balance_of(&token, ADMIN) == 999500, 0);
            assert!(standard_cmtat::balance_of(&token, USER1) == 500, 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_partial_freeze_restriction() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000,
                ADMIN,
                ctx
            );
        };

        // Freeze partial tokens and check restriction
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            // Freeze 600 tokens
            standard_cmtat::freeze_partial_tokens(&mut token, ADMIN, 600, ctx);
            
            // Active balance should be 400
            assert!(standard_cmtat::get_active_balance_of(&token, ADMIN) == 400, 0);
            
            // Trying to transfer 500 should be restricted (insufficient active balance)
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 500);
            assert!(code == icmtat::restriction_code_insufficient_balance(), 1);
            
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
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Create snapshot
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);
            
            standard_cmtat::schedule_snapshot(&mut token, &clock_obj, ctx);
            
            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_mint() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Batch mint
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            let recipients = vector[USER1, USER2];
            let amounts = vector[1000, 2000];
            
            standard_cmtat::batch_mint(&mut token, recipients, amounts, ctx);
            
            assert!(standard_cmtat::balance_of(&token, USER1) == 1000, 0);
            assert!(standard_cmtat::balance_of(&token, USER2) == 2000, 1);
            assert!(standard_cmtat::total_supply(&token) == 3000, 2);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }
}
