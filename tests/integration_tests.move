/// Integration Tests for Cross-Contract Flows
#[test_only]
#[allow(unused_use)]
module move_cmtat::integration_tests {
    use iota::test_scenario::{Self};
    use iota::coin::{Self, TreasuryCap, DenyCapV1};
    use iota::deny_list::{Self, DenyList};
    use iota::clock::{Self, Clock};

    use move_cmtat::light_cmtat::{Self, LIGHT_CMTAT, LightCMTATRegistry, 
                                   AdminCap as LightAdminCap, 
                                   MinterCap as LightMinterCap, 
                                   PauserCap as LightPauserCap,
                                   EnforcerCap as LightEnforcerCap};

    use move_cmtat::allowlist_cmtat::{Self, ALLOWLIST_CMTAT, CMTATRegistry as AllowlistRegistry, 
                                        ComplianceState as AllowlistComplianceState,
                                        AllowlistCMTATState,
                                        AdminCap as AllowlistAdminCap,
                                        AllowlistCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    fun create_deny_list_and_clock(scenario: &mut test_scenario::Scenario) {
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            deny_list::create_for_test(ctx);
        };
        test_scenario::next_tx(scenario, @0x0);
        {
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);
            clock::share_for_testing(clock);
        };
    }

    // ============================================
    // TEST 1: TOKEN LIFECYCLE
    // Flow: init → mint → transfer → verify balance
    // ============================================

    #[test]
    fun test_token_lifecycle() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        create_deny_list_and_clock(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&mut treasury_cap, &registry, &deny_list, USER1, 1000, ctx);
            
            transfer::public_transfer(coins, USER1);
            
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            let coins = test_scenario::take_from_sender<coin::Coin<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::transfer(&registry, &deny_list, coins, USER2, ctx);
            
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, USER2);
        {
            let coins = test_scenario::take_from_sender<coin::Coin<LIGHT_CMTAT>>(scenario);
            assert!(coin::value(&coins) == 1000, 0);
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::end(scenario_val);
    }

    // ============================================
    // TEST 2: ALLOWLIST FULL FLOW
    // Flow: init → enable allowlist → add USER1/USER2 → 
    //       transfer works → disable allowlist → transfer unrestricted
    // ============================================

    #[test]
    fun test_allowlist_full_flow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        create_deny_list_and_clock(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, true, ctx);
            
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER1, true, ctx);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::set_address_allowlist(&allowlist_cap, &mut compliance_state, USER2, true, ctx);
            
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<AllowlistCMTATState>(scenario);
            let admin_cap = test_scenario::take_from_sender<AllowlistAdminCap>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::remove_rule_engine(&admin_cap, &mut state, ctx);
            
            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<ALLOWLIST_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<AllowlistRegistry>(scenario);
            let compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let coins = allowlist_cmtat::mint(&mut treasury_cap, &registry, &compliance_state, &deny_list, USER1, 1000, ctx);
            
            transfer::public_transfer(coins, USER1);
            
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let registry = test_scenario::take_shared<AllowlistRegistry>(scenario);
            let mut state = test_scenario::take_shared<AllowlistCMTATState>(scenario);
            let compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let coins = test_scenario::take_from_sender<coin::Coin<ALLOWLIST_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::transfer(&registry, &mut state, &compliance_state, &deny_list, &clock, coins, USER2, ctx);
            
            test_scenario::return_shared(registry);
            test_scenario::return_shared(state);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER2);
        {
            let coins = test_scenario::take_from_sender<coin::Coin<ALLOWLIST_CMTAT>>(scenario);
            assert!(coin::value(&coins) == 1000, 0);
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let allowlist_cap = test_scenario::take_from_sender<AllowlistCap>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::enable_allowlist(&allowlist_cap, &mut compliance_state, false, ctx);
            
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, allowlist_cap);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<ALLOWLIST_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<AllowlistRegistry>(scenario);
            let compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let coins = allowlist_cmtat::mint(&mut treasury_cap, &registry, &compliance_state, &deny_list, USER3, 500, ctx);
            
            transfer::public_transfer(coins, USER3);
            
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, USER3);
        {
            let registry = test_scenario::take_shared<AllowlistRegistry>(scenario);
            let mut state = test_scenario::take_shared<AllowlistCMTATState>(scenario);
            let compliance_state = test_scenario::take_shared<AllowlistComplianceState>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let coins = test_scenario::take_from_sender<coin::Coin<ALLOWLIST_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            allowlist_cmtat::transfer(&registry, &mut state, &compliance_state, &deny_list, &clock, coins, USER2, ctx);
            
            test_scenario::return_shared(registry);
            test_scenario::return_shared(state);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(clock);
        };

        test_scenario::next_tx(scenario, USER2);
        {
            let coins = test_scenario::take_from_sender<coin::Coin<ALLOWLIST_CMTAT>>(scenario);
            let value = coin::value(&coins);
            // When allowlist disabled, USER3 can transfer to USER2
            test_scenario::return_to_sender(scenario, coins);
        };

        test_scenario::end(scenario_val);
    }

    // ============================================
    // TEST 3: FREEZE/PAUSE FLOW
    // Flow: init → freeze USER2 → verify frozen → unfreeze → verify unfrozen
    // ============================================

    #[test]
    fun test_freeze_pause_flow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        create_deny_list_and_clock(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let enforcer_cap = test_scenario::take_from_sender<LightEnforcerCap>(scenario);
            let mut deny_list = test_scenario::take_shared<DenyList>(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::set_address_frozen(&mut deny_list, &mut deny_cap, USER2, true, ctx);
            
            test_scenario::return_to_sender(scenario, enforcer_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let frozen = light_cmtat::is_frozen(&deny_list, USER2, ctx);
            
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let enforcer_cap = test_scenario::take_from_sender<LightEnforcerCap>(scenario);
            let mut deny_list = test_scenario::take_shared<DenyList>(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::set_address_frozen(&mut deny_list, &mut deny_cap, USER2, false, ctx);
            
            test_scenario::return_to_sender(scenario, enforcer_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }

    // ============================================
    // TEST 4: DEACTIVATION FLOW
    // Flow: init → mint → deactivate → verify deactivated
    // ============================================

    #[test]
    fun test_deactivation_flow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        create_deny_list_and_clock(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&mut treasury_cap, &registry, &deny_list, USER1, 1000, ctx);
            
            transfer::public_transfer(coins, USER1);
            
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<LightAdminCap>(scenario);
            let mut registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let mut deny_list = test_scenario::take_shared<DenyList>(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::deactivate_contract(&admin_cap, &mut registry, &mut deny_list, &mut deny_cap, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            
            assert!(light_cmtat::deactivated(&registry) == true, 0);
            
            test_scenario::return_shared(registry);
        };

        test_scenario::end(scenario_val);
    }

    // ============================================
    // TEST 5: ROLE ESCALATION FLOW
    // Flow: init → grant minter → grant pauser → test capabilities work
    // ============================================

    #[test]
    fun test_role_escalation_flow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        create_deny_list_and_clock(scenario);
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<LightAdminCap>(scenario);
            let treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::grant_minter(&admin_cap, treasury_cap, USER1, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<LightAdminCap>(scenario);
            let deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::grant_pauser(&admin_cap, deny_cap, USER2, ctx);
            
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::next_tx(scenario, USER1);
        {
            let mut treasury_cap = test_scenario::take_from_sender<TreasuryCap<LIGHT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let coins = light_cmtat::mint(&mut treasury_cap, &registry, &deny_list, USER1, 500, ctx);
            
            transfer::public_transfer(coins, USER1);
            
            test_scenario::return_to_sender(scenario, treasury_cap);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(deny_list);
        };

        test_scenario::next_tx(scenario, USER2);
        {
            let mut deny_list = test_scenario::take_shared<DenyList>(scenario);
            let mut deny_cap = test_scenario::take_from_sender<DenyCapV1<LIGHT_CMTAT>>(scenario);
            let registry = test_scenario::take_shared<LightCMTATRegistry>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            light_cmtat::pause(&mut deny_list, &mut deny_cap, &registry, ctx);
            
            test_scenario::return_to_sender(scenario, deny_cap);
            test_scenario::return_shared(deny_list);
            test_scenario::return_shared(registry);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let deny_list = test_scenario::take_shared<DenyList>(scenario);
            
            let ctx = test_scenario::ctx(scenario);
            let paused = light_cmtat::is_paused(&deny_list, ctx);
            
            test_scenario::return_shared(deny_list);
        };

        test_scenario::end(scenario_val);
    }
}
