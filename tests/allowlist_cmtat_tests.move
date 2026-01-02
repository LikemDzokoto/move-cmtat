#[test_only]
module move_cmtat::allowlist_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock;
    use move_cmtat::allowlist_cmtat::{Self, AllowlistCMTAT, AdminCap};

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
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Check token was created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<AllowlistCMTAT>(), 0);
            
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            
            assert!(allowlist_cmtat::name(&token) == string::utf8(b"Allowlist Token"), 1);
            assert!(allowlist_cmtat::symbol(&token) == string::utf8(b"ALLOW"), 2);
            assert!(allowlist_cmtat::decimals(&token) == 18, 3);
            assert!(allowlist_cmtat::total_supply(&token) == 1000000, 4);
            assert!(allowlist_cmtat::balance_of(&token, ADMIN) == 1000000, 5);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_allowlist_functionality() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Enable allowlist and add USER1
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            // Enable allowlist
            allowlist_cmtat::enable_allowlist(&mut token, true, ctx);
            assert!(allowlist_cmtat::allowlist_enabled(&token), 0);
            
            // Add USER1 to allowlist
            allowlist_cmtat::set_address_allowlist(&mut token, USER1, true, ctx);
            assert!(allowlist_cmtat::is_allowlisted(&token, USER1), 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_partial_freeze() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Mint to USER1 and freeze partial tokens
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            // Mint 1000 tokens to USER1
            allowlist_cmtat::mint(&mut token, USER1, 1000, ctx);
            assert!(allowlist_cmtat::balance_of(&token, USER1) == 1000, 0);
            
            // Freeze 300 tokens
            allowlist_cmtat::freeze_partial_tokens(&mut token, USER1, 300, ctx);
            
            // Active balance should be 700
            assert!(allowlist_cmtat::get_active_balance_of(&token, USER1) == 700, 1);
            
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
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                1000000,
                ADMIN,
                ctx
            );
        };

        // Create snapshot
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);
            
            allowlist_cmtat::schedule_snapshot(&mut token, &clock_obj, ctx);
            
            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_operations() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_token(
                string::utf8(b"Allowlist Token"),
                string::utf8(b"ALLOW"),
                18,
                0,
                ADMIN,
                ctx
            );
        };

        // Batch mint and batch allowlist
        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<AllowlistCMTAT>(scenario);
            let ctx = test_scenario::ctx(scenario);
            
            let recipients = vector[USER1, USER2];
            let amounts = vector[500, 700];
            
            allowlist_cmtat::batch_mint(&mut token, recipients, amounts, ctx);
            
            assert!(allowlist_cmtat::balance_of(&token, USER1) == 500, 0);
            assert!(allowlist_cmtat::balance_of(&token, USER2) == 700, 1);
            
            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }
}
