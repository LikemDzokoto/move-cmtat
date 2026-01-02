#[test_only]
module move_cmtat::debt_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock;
    use move_cmtat::debt_cmtat::{Self, DebtCMTAT, AdminCap, MintCap, DebtCap, SnapshotCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const DEBT_ENGINE: address = @0xDEBT;

    // ========== INIT TOKEN TEST ==========
    // IOTA Native: Tests initialization with shared objects and capabilities

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
                0,
                ADMIN,
                ctx
            );
        };

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<DebtCMTAT>(), 0);

            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);

            // Verify token metadata (no balance_of calls)
            assert!(debt_cmtat::name(&token) == string::utf8(b"Corporate Bond"), 1);
            assert!(debt_cmtat::symbol(&token) == string::utf8(b"BOND"), 2);
            assert!(debt_cmtat::decimals(&token) == 18, 3);
            assert!(debt_cmtat::total_supply(&token) == 0, 4);

            // Verify compliance state
            assert!(!debt_cmtat::paused(&compliance_state), 5);
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 6);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SET DEBT TEST ==========
    // IOTA Native: Tests debt information updates

    #[test]
    fun test_set_debt() {
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<debt_cmtat::DebtCap>(scenario);

            // Set debt information
            let debt_info = string::utf8(b"5% Annual Coupon Bond");
            debt_cmtat::set_debt(&debt_cap, &mut compliance_state, debt_info);

            // Verify debt information was set
            assert!(debt_cmtat::debt(&compliance_state) == debt_info, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SET CREDIT EVENTS TEST ==========
    // IOTA Native: Tests credit event tracking

    #[test]
    fun test_set_credit_events() {
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<debt_cmtat::DebtCap>(scenario);

            // Set credit events
            let credit_events = string::utf8(b"Coupon payment on 2024-01-01");
            debt_cmtat::set_credit_events(&debt_cap, &mut compliance_state, credit_events);

            // Verify credit events were set
            assert!(debt_cmtat::credit_events(&compliance_state) == credit_events, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== FLAG DEFAULT TEST ==========
    // IOTA Native: Tests default flag functionality

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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<debt_cmtat::DebtCap>(scenario);

            // Verify initially not in default
            assert!(!debt_cmtat::is_default_flagged(&compliance_state), 0);

            // Flag default
            debt_cmtat::flag_default(&debt_cap, &mut compliance_state);

            // Verify now flagged as default
            assert!(debt_cmtat::is_default_flagged(&compliance_state), 1);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== OPERATIONS WHEN DEFAULT TEST ==========
    // IOTA Native: Tests that operations are blocked when defaulted

    #[test]
    #[expected_failure]
    fun test_operations_when_default() {
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<debt_cmtat::DebtCap>(scenario);
            let mint_cap = test_scenario::take_from_sender<debt_cmtat::MintCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Flag default
            debt_cmtat::flag_default(&debt_cap, &mut compliance_state);

            // Try to mint - should fail when defaulted
            debt_cmtat::mint(&mint_cap, &mut token, &compliance_state, USER1, 1000, ctx);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SET DEBT ENGINE TEST ==========
    // IOTA Native: Tests debt engine address management

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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let compliance_state = test_scenario::take_shared<debt_cmtat::ComplianceState>(scenario);
            let debt_cap = test_scenario::take_from_sender<debt_cmtat::DebtCap>(scenario);

            // Set debt engine address
            debt_cmtat::set_debt_engine(&debt_cap, &mut compliance_state, DEBT_ENGINE);

            // Verify debt engine was set
            assert!(debt_cmtat::debt_engine(&compliance_state) == DEBT_ENGINE, 0);

            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, debt_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SNAPSHOT TEST ==========
    // IOTA Native: Tests snapshot with debt context

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
                0,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<DebtCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<debt_cmtat::SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            // Create snapshot
            debt_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }
}</content>
<parameter name="filePath">/mnt/c/Users/Likem/Documents/move-cmtat/tests/debt_cmtat_tests.move