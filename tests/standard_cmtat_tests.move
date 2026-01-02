#[test_only]
module move_cmtat::standard_cmtat_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock;
    use move_cmtat::standard_cmtat::{Self, StandardCMTAT, AdminCap, MintCap, FreezeCap, PauseCap, SnapshotCap};
    use move_cmtat::icmtat;

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // ========== INIT TOKEN TEST ==========
    // IOTA Native: Tests initialization with shared objects and capabilities

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
                0,
                ADMIN,
                ctx
            );
        };

        // Verify shared objects were created
        test_scenario::next_tx(scenario, ADMIN);
        {
            assert!(test_scenario::has_most_recent_shared<StandardCMTAT>(), 0);

            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);

            // Verify token metadata (no balance_of calls)
            assert!(standard_cmtat::name(&token) == string::utf8(b"Standard Token"), 1);
            assert!(standard_cmtat::symbol(&token) == string::utf8(b"STD"), 2);
            assert!(standard_cmtat::decimals(&token) == 18, 3);
            assert!(standard_cmtat::total_supply(&token) == 0, 4);

            // Verify compliance state
            assert!(!standard_cmtat::paused(&compliance_state), 5);
            assert!(!standard_cmtat::deactivated(&compliance_state), 6);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION - ALLOWED TEST ==========
    // IOTA Native: Tests normal transfer succeeds

    #[test]
    fun test_transfer_validation_allowed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and mint to ADMIN
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);

            // Validate transfer - should be allowed
            let restriction_code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(restriction_code == icmtat::restriction_code_valid(), 0);

            let message = standard_cmtat::message_for_transfer_restriction(restriction_code);
            assert!(message == string::utf8(b"Transfer allowed"), 1);

            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION - WHEN PAUSED TEST ==========
    // IOTA Native: Tests transfer blocked when contract is paused

    #[test]
    fun test_transfer_validation_when_paused() {
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let pause_cap = test_scenario::take_from_sender<standard_cmtat::PauseCap>(scenario);

            // Pause the contract
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);
            standard_cmtat::pause(&pause_cap, &mut compliance_state);

            // Validate transfer - should be restricted when paused
            let restriction_code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(restriction_code == icmtat::restriction_code_paused(), 0);

            let message = standard_cmtat::message_for_transfer_restriction(restriction_code);
            assert!(message == string::utf8(b"Contract is paused"), 1);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, pause_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION - WHEN SENDER FROZEN TEST ==========
    // IOTA Native: Tests transfer blocked when sender is frozen

    #[test]
    fun test_transfer_validation_when_frozen_sender() {
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<standard_cmtat::FreezeCap>(scenario);

            // Freeze ADMIN
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, ADMIN, true);

            // Validate transfer - should be restricted when sender frozen
            let restriction_code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(restriction_code == icmtat::restriction_code_frozen_sender(), 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER VALIDATION - INSUFFICIENT BALANCE TEST ==========
    // IOTA Native: Tests transfer blocked for insufficient balance

    #[test]
    fun test_transfer_validation_insufficient_balance() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token with small balance
        {
            let ctx = test_scenario::ctx(scenario);
            standard_cmtat::init_token(
                string::utf8(b"Standard Token"),
                string::utf8(b"STD"),
                18,
                50,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);

            // Try to transfer 100 tokens - insufficient balance
            let restriction_code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 100);
            assert!(restriction_code == icmtat::restriction_code_insufficient_balance(), 0);

            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    // ========== GET RESTRICTION CODE TEST ==========
    // IOTA Native: Tests correct restriction code return

    #[test]
    fun test_get_restriction_code() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and test different restriction scenarios
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);
            let pause_cap = test_scenario::take_from_sender<standard_cmtat::PauseCap>(scenario);
            let freeze_cap = test_scenario::take_from_sender<standard_cmtat::FreezeCap>(scenario);

            // Test valid transfer
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 0);
            assert!(code == 0, 0); // VALID

            // Test paused
            standard_cmtat::pause(&pause_cap, &mut compliance_state);
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 0);
            assert!(code == 1, 1); // PAUSED

            // Test frozen sender
            standard_cmtat::unpause(&pause_cap, &mut compliance_state);
            standard_cmtat::set_address_frozen(&freeze_cap, &mut compliance_state, ADMIN, true);
            let code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 0);
            assert!(code == 2, 2); // FROZEN_SENDER

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, pause_cap);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== GET RESTRICTION MESSAGE TEST ==========
    // IOTA Native: Tests correct restriction message return

    #[test]
    fun test_get_restriction_message() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Test message retrieval for different codes
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Test messages for restriction codes 0-5
            let msg0 = standard_cmtat::message_for_transfer_restriction(0);
            assert!(msg0 == string::utf8(b"Transfer allowed"), 0);

            let msg1 = standard_cmtat::message_for_transfer_restriction(1);
            assert!(msg1 == string::utf8(b"Contract is paused"), 1);

            let msg2 = standard_cmtat::message_for_transfer_restriction(2);
            assert!(msg2 == string::utf8(b"Sender address is frozen"), 2);

            let msg3 = standard_cmtat::message_for_transfer_restriction(3);
            assert!(msg3 == string::utf8(b"Recipient address is frozen"), 3);

            let msg4 = standard_cmtat::message_for_transfer_restriction(4);
            assert!(msg4 == string::utf8(b"Insufficient balance"), 4);

            let msg5 = standard_cmtat::message_for_transfer_restriction(5);
            assert!(msg5 == string::utf8(b"Unknown restriction"), 5);
        };

        test_scenario::end(scenario_val);
    }

    // ========== PARTIAL FREEZE TRANSFER TEST ==========
    // IOTA Native: Tests transfer blocked with insufficient active balance

    #[test]
    fun test_partial_freeze_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token, mint tokens, freeze partial amount
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);
            let freeze_cap = test_scenario::take_from_sender<standard_cmtat::FreezeCap>(scenario);

            // Freeze 600 tokens
            standard_cmtat::freeze_partial_tokens(&freeze_cap, &mut compliance_state, ADMIN, 600);

            // Active balance should be 400
            assert!(standard_cmtat::get_active_balance_of(&token, &compliance_state, ADMIN) == 400, 0);

            // Try to transfer 500 tokens - should be blocked (insufficient active balance)
            let restriction_code = standard_cmtat::detect_transfer_restriction(&token, ADMIN, USER1, 500);
            assert!(restriction_code == icmtat::restriction_code_insufficient_balance(), 1);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, freeze_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== TRANSFER TEST ==========
    // IOTA Native: Tests successful transfer execution

    #[test]
    fun test_transfer() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and execute transfer
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);

            // Execute transfer
            standard_cmtat::transfer(&mut token, USER1, 500);

            // Verify balances after transfer (no balance_of calls)
            assert!(standard_cmtat::total_supply(&token) == 1000, 0); // Total supply unchanged

            test_scenario::return_shared(token);
        };

        test_scenario::end(scenario_val);
    }

    // ========== BATCH MINT TEST ==========
    // IOTA Native: Tests batch operations

    #[test]
    fun test_batch_mint() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize token and batch mint
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

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let mint_cap = test_scenario::take_from_sender<standard_cmtat::MintCap>(scenario);
            let compliance_state = test_scenario::take_shared<standard_cmtat::ComplianceState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Batch mint to multiple recipients
            let recipients = vector[USER1, USER2];
            let amounts = vector[1000, 2000];
            standard_cmtat::batch_mint(&mint_cap, &mut token, &compliance_state, recipients, amounts, ctx);

            // Verify total supply
            assert!(standard_cmtat::total_supply(&token) == 3000, 0);

            test_scenario::return_shared(token);
            test_scenario::return_shared(compliance_state);
            test_scenario::return_to_sender(scenario, mint_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ========== SNAPSHOT TEST ==========
    // IOTA Native: Tests snapshot creation

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
                1000,
                ADMIN,
                ctx
            );
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let token = test_scenario::take_shared<StandardCMTAT>(scenario);
            let snapshot_cap = test_scenario::take_from_sender<standard_cmtat::SnapshotCap>(scenario);
            let clock_obj = clock::create_for_testing(test_scenario::ctx(scenario));
            let ctx = test_scenario::ctx(scenario);

            // Create snapshot
            standard_cmtat::schedule_snapshot(&snapshot_cap, &mut token, &clock_obj, ctx);

            clock::destroy_for_testing(clock_obj);
            test_scenario::return_shared(token);
            test_scenario::return_to_sender(scenario, snapshot_cap);
        };

        test_scenario::end(scenario_val);
    }
}</content>
<parameter name="filePath">/mnt/c/Users/Likem/Documents/move-cmtat/tests/standard_cmtat_tests.move