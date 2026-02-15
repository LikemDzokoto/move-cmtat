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
            let mut state = test_scenario::take_shared<DebtEngineState>(scenario);

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
}
