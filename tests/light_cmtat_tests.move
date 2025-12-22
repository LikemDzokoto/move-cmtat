#[test_only]
module move_cmtat::light_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use move_cmtat::light_cmtat::{Self, LightCMTAT, AdminCap};

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
            light_cmtat::init_token(
                string::utf8(b"Test Token"),
                string::utf8(b"TEST"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Check token was created and shared
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<LightCMTAT>(), 0);
            
            let token = test_scenario::take_shared<LightCMTAT>(scenario);
            
            assert!(light_cmtat::name(&token) == string::utf8(b"Test Token"), 1);
            assert!(light_cmtat::symbol(&token) == string::utf8(b"TEST"), 2);
            assert!(light_cmtat::decimals(&token) == 18, 3);
            assert!(light_cmtat::total_supply(&token) == 1000000, 4);
            assert!(light_cmtat::balance_of(&token, ADMIN) == 1000000, 5);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mint() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_token(
                string::utf8(b"Test Token"),
                string::utf8(b"TEST"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Mint to USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<LightCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            light_cmtat::mint(&mut token, USER1, 5000, ctx);
            
            assert!(light_cmtat::balance_of(&token, USER1) == 5000, 0);
            assert!(light_cmtat::total_supply(&token) == 5000, 1);
            
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
            light_cmtat::init_token(
                string::utf8(b"Test Token"),
                string::utf8(b"TEST"),
                18,
                0,
                ADMIN,
                ctx
            );
        };
