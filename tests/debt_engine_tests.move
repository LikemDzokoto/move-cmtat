/// DebtEngine Test Suite - Tests for multi-token debt management
#[test_only]
#[allow(unused_use, unused_function, unused_const)]
module move_cmtat::debt_engine_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};
    use iota::clock::{Self, Clock};

    use move_cmtat::debt_engine::{Self, DebtEngineState, DebtEngineAdminCap};
    use move_cmtat::debt::{Self, DebtIdentifier, DebtInstrument, BondTerms, CreditEvents};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;
    const TOKEN1: address = @0x1;
    const TOKEN2: address = @0x2;

    // ============ HELPER FUNCTIONS ============

    fun create_debt_identifier(): DebtIdentifier {
        debt::init_debt_identifier()
    }

    fun create_debt_instrument(): DebtInstrument {
        debt::init_debt_instrument()
    }

    fun create_bond_terms(): BondTerms {
        debt::init_bond_terms()
    }

    fun create_credit_events(): CreditEvents {
        debt::init_credit_events()
    }

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_debt_engine_initial_state() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);

            assert!(debt_engine::get_token_count(&state) == 0, 0);
            assert!(debt_engine::get_admin_address(&state) == ADMIN, 1);

            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_admin_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);

            assert!(debt_engine::get_admin_address(&state) == ADMIN, 0);

            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    // ============ TOKEN REGISTRATION TESTS ============

    #[test]
    fun test_register_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let identifier = create_debt_identifier();
            let instrument = create_debt_instrument();
            let terms = create_bond_terms();

            debt_engine::register_token(
                &cap,
                &mut state,
                TOKEN1,
                identifier,
                instrument,
                terms,
                1704067200,
                ctx,
            );

            assert!(debt_engine::is_token_registered(&state, TOKEN1), 0);
            assert!(debt_engine::get_token_count(&state) == 1, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_register_multiple_tokens() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN2,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(debt_engine::get_token_count(&state) == 2, 0);

            let tokens = debt_engine::get_registered_tokens(&state);
            assert!(vector::length(&tokens) == 2, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ============ CREDIT EVENT TESTS ============

    #[test]
    fun test_flag_token_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 0);

            debt_engine::flag_token_default(&cap, &mut state, TOKEN1, &clock, ctx);

            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_clear_token_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            debt_engine::flag_token_default(&cap, &mut state, TOKEN1, &clock, ctx);
            assert!(debt_engine::is_token_in_default(&state, TOKEN1), 0);

            debt_engine::clear_token_default(&cap, &mut state, TOKEN1, &clock, ctx);
            assert!(!debt_engine::is_token_in_default(&state, TOKEN1), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_token_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(!debt_engine::is_token_redeemed(&state, TOKEN1), 0);

            debt_engine::flag_token_redeemed(&cap, &mut state, TOKEN1, &clock, ctx);

            assert!(debt_engine::is_token_redeemed(&state, TOKEN1), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_flag_token_matured() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(!debt_engine::is_token_matured(&state, TOKEN1), 0);

            debt_engine::flag_token_matured(&cap, &mut state, TOKEN1, &clock, ctx);

            assert!(debt_engine::is_token_matured(&state, TOKEN1), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ QUERY TESTS ============

    #[test]
    fun test_get_token_debt_data() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let _data = debt_engine::get_token_debt_data(&state, TOKEN1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_registered_tokens() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);

            let tokens = debt_engine::get_registered_tokens(&state);
            assert!(vector::length(&tokens) == 0, 0);

            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_engine_stats() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let (total, defaulted, redeemed) = debt_engine::get_engine_stats(&state);
            assert!(total == 0, 0);
            assert!(defaulted == 0, 1);
            assert!(redeemed == 0, 2);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let (total2, _, _) = debt_engine::get_engine_stats(&state);
            assert!(total2 == 1, 3);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_require_token_registered() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap,
                &mut state,
                TOKEN1,
                create_debt_identifier(),
                create_debt_instrument(),
                create_bond_terms(),
                1704067200,
                ctx,
            );

            debt_engine::require_token_registered(&state, TOKEN1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_unregister_token() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(debt_engine::is_token_registered(&state, TOKEN1), 0);

            debt_engine::unregister_token(&cap, &mut state, TOKEN1, 1704067200, ctx);

            assert!(!debt_engine::is_token_registered(&state, TOKEN1), 1);
            assert!(debt_engine::get_token_count(&state) == 0, 2);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ============ TOKEN UPDATE TESTS ============

    #[test]
    fun test_update_token_identifier() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let new_identifier = debt::create_debt_identifier(
                string::utf8(b"New Issuer"),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b"NEW123"),
            );

            debt_engine::update_token_identifier(
                &cap, &mut state, TOKEN1, new_identifier, 1704153600, ctx,
            );

            let id = debt_engine::get_token_identifier(&state, TOKEN1);
            assert!(debt::identifier_get_issuer_name(&id) == string::utf8(b"New Issuer"), 0);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_token_instrument() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let new_instrument = debt::create_debt_instrument(
                6_000_000,
                500_000,
                50_000,
                1704067200,
                1767225600,
                string::utf8(b"QUARTERLY"),
                string::utf8(b""),
                string::utf8(b""),
                debt::u8_to_day_count(2),
                debt::u8_to_business_day(3),
                string::utf8(b"EUR"),
                @0x0,
            );

            debt_engine::update_token_instrument(
                &cap, &mut state, TOKEN1, new_instrument, 1704153600, ctx,
            );

            let inst = debt_engine::get_token_instrument(&state, TOKEN1);
            assert!(debt::instrument_get_interest_rate(&inst) == 6_000_000, 0);
            assert!(debt::instrument_get_par_value(&inst) == 500_000, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_token_terms() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let new_terms = debt::create_bond_terms(
                string::utf8(b"Callable after 2025"),
                string::utf8(b"Puttable after 2024"),
                string::utf8(b""),
                string::utf8(b""),
                string::utf8(b"Unsecured"),
            );

            debt_engine::update_token_terms(
                &cap, &mut state, TOKEN1, new_terms, 1704153600, ctx,
            );

            let terms = debt_engine::get_token_terms(&state, TOKEN1);
            assert!(debt::bond_terms_get_call_schedule(&terms) == string::utf8(b"Callable after 2025"), 0);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_token_rating() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(debt_engine::get_token_rating(&state, TOKEN1) == string::utf8(b""), 0);

            debt_engine::update_token_rating(
                &cap, &mut state, TOKEN1, string::utf8(b"AA+"), &clock, ctx,
            );

            assert!(debt_engine::get_token_rating(&state, TOKEN1) == string::utf8(b"AA+"), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_record_token_principal_distribution() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let events = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(debt::credit_events_get_principal_distributed(&events) == 0, 0);

            debt_engine::record_token_principal_distribution(
                &cap, &mut state, TOKEN1, 500_000, &clock, ctx,
            );

            let events2 = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(debt::credit_events_get_principal_distributed(&events2) == 500_000, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ TOKEN GETTER TESTS ============

    #[test]
    fun test_get_token_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let events = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(!debt::credit_events_is_default(&events), 0);
            assert!(!debt::credit_events_is_redeemed(&events), 1);
            assert!(!debt::credit_events_is_matured(&events), 2);

            debt_engine::flag_token_default(&cap, &mut state, TOKEN1, &clock, ctx);
            let events2 = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(debt::credit_events_is_default(&events2), 3);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_token_interest_rate_and_maturity() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let instrument = debt::create_debt_instrument(
                5_500_000, 1_000_000, 100_000, 1704067200, 1767225600,
                string::utf8(b"ANNUAL"), string::utf8(b""), string::utf8(b""),
                debt::u8_to_day_count(2), debt::u8_to_business_day(3),
                string::utf8(b"USD"), @0x0,
            );

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), instrument, create_bond_terms(),
                1704067200, ctx,
            );

            assert!(debt_engine::get_token_interest_rate(&state, TOKEN1) == 5_500_000, 0);
            assert!(debt_engine::get_token_maturity_date(&state, TOKEN1) == 1767225600, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_token_registration_and_last_updated_time() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            assert!(debt_engine::get_token_registration_time(&state, TOKEN1) == 1704067200, 0);
            assert!(debt_engine::get_token_last_updated(&state, TOKEN1) == 1704067200, 1);

            let new_instrument = debt::create_debt_instrument(
                6_000_000, 500_000, 50_000, 1704067200, 1767225600,
                string::utf8(b""), string::utf8(b""), string::utf8(b""),
                debt::u8_to_day_count(2), debt::u8_to_business_day(3),
                string::utf8(b""), @0x0,
            );
            debt_engine::update_token_instrument(
                &cap, &mut state, TOKEN1, new_instrument, 1704153600, ctx,
            );

            assert!(debt_engine::get_token_last_updated(&state, TOKEN1) == 1704153600, 2);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_try_get_token_debt_data() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);

            let result = debt_engine::try_get_token_debt_data(&state, TOKEN1);
            assert!(option::is_none(&result), 0);

            test_scenario::return_shared(state);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let result = debt_engine::try_get_token_debt_data(&state, TOKEN1);
            assert!(option::is_some(&result), 1);

            let _data = option::destroy_some(result);
            assert!(debt_engine::get_token_registration_time(&state, TOKEN1) == 1704067200, 2);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    // ============ REQUIRE / ASSERTION TESTS ============

    #[test]
    fun test_require_token_not_in_default() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            debt_engine::require_token_not_in_default(&state, TOKEN1);
            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_require_token_not_redeemed() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            debt_engine::require_token_not_redeemed(&state, TOKEN1);
            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ ADMIN / BATCH TESTS ============

    #[test]
    fun test_update_admin_address() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);

            assert!(debt_engine::get_admin_address(&state) == ADMIN, 0);

            debt_engine::update_admin_address(&cap, &mut state, TOKEN1);

            assert!(debt_engine::get_admin_address(&state) == TOKEN1, 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_register_token_full() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let initial_events = debt::create_credit_events(
                true, false, false, string::utf8(b"AA"), 0, 0,
            );

            debt_engine::register_token_full(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                initial_events, 1704067200, ctx,
            );

            let events = debt_engine::get_token_credit_events(&state, TOKEN1);
            assert!(debt::credit_events_is_default(&events), 0);
            assert!(debt::credit_events_get_rating(&events) == string::utf8(b"AA"), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_batch_update_credit_events() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let clock = clock::create_for_testing(ctx);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );
            debt_engine::register_token(
                &cap, &mut state, TOKEN2,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            let new_events = debt::create_credit_events(
                true, false, false, string::utf8(b"BBB"), 0, 0,
            );

            debt_engine::batch_update_credit_events(
                &cap, &mut state, vector[TOKEN1, TOKEN2], new_events, &clock, ctx,
            );

            let ev1 = debt_engine::get_token_credit_events(&state, TOKEN1);
            let ev2 = debt_engine::get_token_credit_events(&state, TOKEN2);
            assert!(debt::credit_events_is_default(&ev1), 0);
            assert!(debt::credit_events_is_default(&ev2), 1);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(clock);
        };

        test_scenario::end(scenario_val);
    }

    // ============ ABORT TESTS ============

    #[test]
    #[expected_failure(abort_code = debt_engine::ETokenAlreadyRegistered)]
    fun test_register_token_duplicate_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            debt_engine::register_token(
                &cap, &mut state, TOKEN1,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_engine::EInvalidTokenAddress)]
    fun test_register_token_zero_address_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::register_token(
                &cap, &mut state, @0x0,
                create_debt_identifier(), create_debt_instrument(), create_bond_terms(),
                1704067200, ctx,
            );

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_engine::ETokenNotRegistered)]
    fun test_update_unregistered_token_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::update_token_instrument(
                &cap, &mut state, TOKEN1,
                create_debt_instrument(), 1704067200, ctx,
            );

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_engine::ETokenNotRegistered)]
    fun test_unregister_unregistered_token_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);
            let cap = test_scenario::take_from_sender<DebtEngineAdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            debt_engine::unregister_token(&cap, &mut state, TOKEN1, 1704067200, ctx);

            test_scenario::return_to_sender(scenario, cap);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = debt_engine::ETokenNotRegistered)]
    fun test_get_token_debt_data_unregistered_aborts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let (state, cap) = debt_engine::init_debt_engine(ctx);
            transfer::public_share_object(state);
            transfer::public_transfer(cap, ADMIN);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let state = test_scenario::take_shared<DebtEngineState>(scenario);
            let _data = debt_engine::get_token_debt_data(&state, TOKEN1);
            test_scenario::return_shared(state);
        };

        test_scenario::end(scenario_val);
    }
}
