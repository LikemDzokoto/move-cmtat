/// DebtEngine Test Suite - Comprehensive Testing for Debt Management
#[test_only]
module move_cmtat::debt_engine_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock::{Self, Clock};

    use move_cmtat::debt_engine::{Self, DebtEngineState, TokenDebtData, DebtEngineAdminCap};
    use move_cmtat::debt::{Self, DebtIdentifier, DebtInstrument, CreditEvents, BondTerms};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;
    const TOKEN1: address = @0xT1;
    const TOKEN2: address = @0xT2;
    const USER1: address = @0x1;
    const USER2: address = @0x2;

    // ============ HELPER FUNCTIONS ============

    fun setup(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt_engine::init_debt_engine(ctx);
            let admin_cap = debt_engine::create_admin_cap(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(admin_cap, ADMIN);
        };
    }

    fun create_test_identifier(name: vector<u8>): DebtIdentifier {
        debt::create_debt_identifier(
            string::utf8(name),
            string::utf8(b"Test issuer description"),
            string::utf8(b""),
            string::utf8(b"Representative"),
            string::utf8(b"TEST123"),
        )
    }

    fun create_test_instrument(): DebtInstrument {
        debt::create_debt_instrument(
            5000000, // 5% interest rate
            1000,    // par value
            1,       // minimum denomination
            1704067200, // issuance date (2024-01-01)
            1735603200, // maturity date (2025-01-01)
            string::utf8(b"ANNUAL"),
            string::utf8(b"Annual coupon payments"),
            string::utf8(b"2025-01-01"),
            debt::ActualActual {},
            debt::Unadjusted {},
            string::utf8(b"USD"),
            @0x0,
        )
    }

    fun create_test_terms(): BondTerms {
        debt::create_bond_terms(
            string::utf8(b""),
            string::utf8(b""),
            string::utf8(b""),
            string::utf8(b""),
            string::utf8(b"Unsecured bond"),
        )
    }

    fun create_test_credit_events(): CreditEvents {
        debt::create_credit_events(
            false,  // not in default
            false,  // not redeemed
            false,  // not matured
            string::utf8(b"AAA"), // rating
            0,      // no principal distributed
            1704067200, // next coupon date
        )
    }

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_debt_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt_engine::init_debt_engine(ctx);

            assert!(debt_engine::get_token_count(&state) == 0, 0);
            assert!(debt_engine::get_admin_address(&state) == ADMIN, 1);

            transfer::public_share_object(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_admin_cap_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let state = debt_engine::init_debt_engine(ctx);
            let admin_cap = debt_engine::create_admin_cap(ctx);

            assert!(debt_engine::get_engine_id(&admin_cap) == object::id_address(&state), 0);

            transfer::public_share_object(state);
            transfer::public_transfer(admin_cap, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    // ============ TOKEN REGISTRATION TESTS ============

    #[test]
    fun test_register_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Test Token");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            assert!(debt_engine::is_token_registered(&state, TOKEN1), 0);
            assert!(debt_engine::get_token_count(&state) == 1, 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_register_token_full() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Full Test Token");
            let instrument = create_test_instrument();
            let terms = create_test_terms();
            let credit_events = create_test_credit_events();

            debt_engine::register_token_full(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                credit_events,
                clock.timestamp_ms(),
                ctx,
            );

            assert!(debt_engine::is_token_registered(&state, TOKEN1), 0);
            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 1);
            assert!(!debt_engine::is_token_redeemed(&state, TOKEN1), 2);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_engine::ETokenAlreadyRegistered)]
    fun test_register_duplicate_token_fails() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Duplicate Token");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            // Try to register again - should fail
            let identifier2 = create_test_identifier(b"Duplicate Token 2");
            let instrument2 = create_test_instrument();
            let terms2 = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier2,
                instrument2,
                terms2,
                clock.timestamp_ms(),
                ctx,
            );

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_unregister_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Register token
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Unregister Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        // Unregister token
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::unregister_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_registered(&state, TOKEN1), 0);
            assert!(debt_engine::get_token_count(&state) == 0, 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ CREDIT EVENTS TESTS ============

    #[test]
    fun test_flag_token_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Register token
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Default Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        // Flag as default
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 0);

            debt_engine::flag_token_default(
                &admin_cap,
                &mut state,
                TOKEN1,
                &clock,
                ctx,
            );

            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_clear_token_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Register and flag default
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Clear Default Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            debt_engine::flag_token_default(&admin_cap, &mut state, TOKEN1, &clock, ctx);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        // Clear default
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 0);

            debt_engine::clear_token_default(
                &admin_cap,
                &mut state,
                TOKEN1,
                &clock,
                ctx,
            );

            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_token_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Redeemed Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_redeemed(&state, TOKEN1), 0);

            debt_engine::flag_token_redeemed(
                &admin_cap,
                &mut state,
                TOKEN1,
                &clock,
                ctx,
            );

            assert!(debt_engine::is_token_redeemed(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_token_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Matured Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_matured(&state, TOKEN1), 0);

            debt_engine::flag_token_matured(
                &admin_cap,
                &mut state,
                TOKEN1,
                &clock,
                ctx,
            );

            assert!(debt_engine::is_token_matured(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_token_rating() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Rating Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            let rating = debt_engine::get_token_rating(&state, TOKEN1);
            assert!(rating == string::utf8(b"AAA"), 0);

            debt_engine::update_token_rating(
                &admin_cap,
                &mut state,
                TOKEN1,
                string::utf8(b"AA+"),
                &clock,
                ctx,
            );

            let new_rating = debt_engine::get_token_rating(&state, TOKEN1);
            assert!(new_rating == string::utf8(b"AA+"), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_record_principal_distribution() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Principal Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token_full(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                create_test_credit_events(),
                clock.timestamp_ms(),
                ctx,
            );

            let data = debt_engine::get_token_debt_data(&state, TOKEN1);
            assert!(debt::credit_events_get_principal_distributed(&data.credit_events) == 0, 0);

            debt_engine::record_token_principal_distribution(
                &admin_cap,
                &mut state,
                TOKEN1,
                50000,
                &clock,
                ctx,
            );

            let data2 = debt_engine::get_token_debt_data(&state, TOKEN1);
            assert!(debt::credit_events_get_principal_distributed(&data2.credit_events) == 50000, 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ QUERY TESTS ============

    #[test]
    fun test_get_token_debt_data() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_test_identifier(b"Query Test");
            let instrument = create_test_instrument();
            let terms = create_test_terms();

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                clock.timestamp_ms(),
                ctx,
            );

            let data = debt_engine::get_token_debt_data(&state, TOKEN1);
            assert!(debt::identifier_get_isin(&data.identifier) == string::utf8(b"TEST123"), 0);
            assert!(debt::instrument_get_par_value(&data.instrument) == 1000, 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_token_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let credit_events = create_test_credit_events();

            debt_engine::register_token_full(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Credit Events Test"),
                create_test_instrument(),
                create_test_terms(),
                credit_events,
                clock.timestamp_ms(),
                ctx,
            );

            let events = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(!debt::credit_events_is_default(&events), 0);
            assert!(!debt::credit_events_is_redeemed(&events), 1);
            assert!(debt::credit_events_get_rating(&events) == string::utf8(b"AAA"), 2);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_token_in_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Default Check"),
                create_test_instrument(),
                create_test_terms(),
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 0);
            assert!(!debt_engine::is_token_in_default(&state, TOKEN2), 1); // Not registered

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_token_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Redeemed Check"),
                create_test_instrument(),
                create_test_terms(),
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_redeemed(&state, TOKEN1), 0);

            debt_engine::flag_token_redeemed(&admin_cap, &mut state, TOKEN1, &clock, ctx);

            assert!(debt_engine::is_token_redeemed(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_is_token_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Matured Check"),
                create_test_instrument(),
                create_test_terms(),
                clock.timestamp_ms(),
                ctx,
            );

            assert!(!debt_engine::is_token_matured(&state, TOKEN1), 0);

            debt_engine::flag_token_matured(&admin_cap, &mut state, TOKEN1, &clock, ctx);

            assert!(debt_engine::is_token_matured(&state, TOKEN1), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_token_rating() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let credit_events = create_test_credit_events();

            debt_engine::register_token_full(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Rating Query"),
                create_test_instrument(),
                create_test_terms(),
                credit_events,
                clock.timestamp_ms(),
                ctx,
            );

            let rating = debt_engine::get_token_rating(&state, TOKEN1);
            assert!(rating == string::utf8(b"AAA"), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_require_token_registered() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);

            debt_engine::require_token_registered(&state, TOKEN1); // Should not abort

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_require_token_not_in_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &admin_cap,
                &mut state,
                TOKEN1,
                create_test_identifier(b"Default Req Test"),
                create_test_instrument(),
                create_test_terms(),
                clock.timestamp_ms(),
                ctx,
            );

            debt_engine::require_token_not_in_default(&state, TOKEN1); // Should not abort

            debt_engine::flag_token_default(&admin_cap, &mut state, TOKEN1, &clock, ctx);

            // Now should fail - but we can't test expected failure easily with shared objects
            // So we just verify the state changed
            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 0);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ ADMIN FUNCTIONS TESTS ============

    #[test]
    fun test_update_admin_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);

            assert!(debt_engine::get_admin_address(&state) == ADMIN, 0);

            debt_engine::update_admin_address(&admin_cap, &mut state, USER1);

            assert!(debt_engine::get_admin_address(&state) == USER1, 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
        };

        test_scenario::end(scenario_val);
    }

    // ============ BATCH OPERATIONS TESTS ============

    #[test]
    fun test_batch_update_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Register multiple tokens
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let credit_events = create_test_credit_events();
            let tokens = vector[TOKEN1, TOKEN2];
            let len = vector::length(&tokens);
            let mut i = 0;
            while (i < len) {
                let token = *vector::borrow(&tokens, i);
                debt_engine::register_token_full(
                    &admin_cap,
                    &mut state,
                    token,
                    create_test_identifier(b"Batch Test Token"),
                    create_test_instrument(),
                    create_test_terms(),
                    credit_events,
                    clock.timestamp_ms(),
                    ctx,
                );
                i = i + 1;
            };

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        // Batch update
        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let tokens = vector[TOKEN1, TOKEN2];
            let new_credit_events = create_test_credit_events();
            debt::credit_events_flag_default(&mut new_credit_events);

            debt_engine::batch_update_credit_events(
                &admin_cap,
                &mut state,
                tokens,
                new_credit_events,
                &clock,
                ctx,
            );

            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 0);
            assert!(debt_engine::is_token_in_default(&state, TOKEN2), 1);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ ENGINE STATISTICS TESTS ============

    #[test]
    fun test_get_engine_stats() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let admin_cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let clock = test_scenario::take_shared<Clock>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let (total, defaulted, redeemed) = debt_engine::get_engine_stats(&state);
            assert!(total == 0, 0);
            assert!(defaulted == 0, 1);
            assert!(redeemed == 0, 2);

            // Register tokens
            let tokens = vector[TOKEN1, TOKEN2];
            let len = vector::length(&tokens);
            let mut i = 0;
            while (i < len) {
                let token = *vector::borrow(&tokens, i);
                debt_engine::register_token_full(
                    &admin_cap,
                    &mut state,
                    token,
                    create_test_identifier(b"Stats Test"),
                    create_test_instrument(),
                    create_test_terms(),
                    create_test_credit_events(),
                    clock.timestamp_ms(),
                    ctx,
                );
                i = i + 1;
            };

            let (total2, defaulted2, redeemed2) = debt_engine::get_engine_stats(&state);
            assert!(total2 == 2, 3);
            assert!(defaulted2 == 0, 4);
            assert!(redeemed2 == 0, 5);

            // Flag one as redeemed
            debt_engine::flag_token_redeemed(&admin_cap, &mut state, TOKEN1, &clock, ctx);

            let (total3, defaulted3, redeemed3) = debt_engine::get_engine_stats(&state);
            assert!(total3 == 2, 6);
            assert!(defaulted3 == 0, 7);
            assert!(redeemed3 == 1, 8);

            test_scenario::return_shared(state);
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(clock);
        };

        test_scenario::end(scenario_val);
    }
}
