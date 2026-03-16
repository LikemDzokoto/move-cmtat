/// InterestEngine Test Suite - Tests for coupon schedule and interest calculations
#[test_only]
#[allow(unused_use, unused_function, unused_const)]
module move_cmtat::interest_engine_tests {
    use iota::test_scenario::{Self, Scenario};

    use move_cmtat::interest_engine::{Self, InterestEngineState};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_interest_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);

            assert!(interest_engine::get_total_coupons(&engine) == 0, 0);
            assert!(interest_engine::get_total_interest_paid(&engine) == 0, 1);
            assert!(!interest_engine::is_schedule_generated(&engine), 2);

            transfer::public_share_object(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_empty_schedule() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<InterestEngineState>(scenario);

            assert!(interest_engine::get_total_coupons(&engine) == 0, 0);
            assert!(interest_engine::get_coupons_remaining(&engine) == 0, 1);
            assert!(interest_engine::get_next_coupon_number(&engine) == 1, 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ SCHEDULE GENERATION TESTS ============

    #[test]
    fun test_generate_coupon_schedule_annual() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            assert!(interest_engine::is_schedule_generated(&engine), 0);
            assert!(interest_engine::get_total_coupons(&engine) == 1, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_generate_coupon_schedule_semiannual() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"SEMI_ANNUAL"),
                5000000,
                1000,
                100000,
                1,
                ctx,
            );

            assert!(interest_engine::is_schedule_generated(&engine), 0);
            assert!(interest_engine::get_total_coupons(&engine) >= 1, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_generate_coupon_schedule_quarterly() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"QUARTERLY"),
                5000000,
                1000,
                100000,
                2,
                ctx,
            );

            assert!(interest_engine::is_schedule_generated(&engine), 0);
            assert!(interest_engine::get_total_coupons(&engine) >= 3, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ COUPON QUERY TESTS ============

    #[test]
    fun test_get_coupon() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let coupon = interest_engine::get_coupon(&engine, 1);
            assert!(interest_engine::coupon_get_number(&coupon) == 1, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_coupon_exists() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            assert!(interest_engine::coupon_exists(&engine, 1), 0);
            assert!(!interest_engine::coupon_exists(&engine, 2), 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_next_coupon() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let next = interest_engine::get_next_coupon(&engine);
            assert!(option::is_some(&next), 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ PAYMENT TESTS ============

    #[test]
    fun test_record_coupon_payment() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            interest_engine::record_coupon_payment(&mut engine, 1, 1735603200, ctx);

            assert!(interest_engine::get_coupons_paid(&engine) == 1, 0);
            assert!(interest_engine::get_total_interest_paid(&engine) > 0, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_unpaid_coupons() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"SEMI_ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let unpaid = interest_engine::get_unpaid_coupons(&engine);
            assert!(vector::length(&unpaid) >= 1, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_paid_coupons() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            interest_engine::record_coupon_payment(&mut engine, 1, 1735603200, ctx);

            let paid = interest_engine::get_paid_coupons(&engine);
            assert!(vector::length(&paid) == 1, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ INTEREST CALCULATION TESTS ============

    #[test]
    fun test_calculate_account_interest() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let interest = interest_engine::calculate_account_interest(&engine, 1, 50000);
            assert!(interest > 0, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_are_all_coupons_paid() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            assert!(!interest_engine::are_all_coupons_paid(&engine), 0);

            interest_engine::record_coupon_payment(&mut engine, 1, 1735603200, ctx);

            assert!(interest_engine::are_all_coupons_paid(&engine), 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_get_first_payment_date() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let first_date = interest_engine::get_first_payment_date(&engine);
            assert!(first_date > 1704067200, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_estimated_total_interest() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = interest_engine::init_interest_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<InterestEngineState>(scenario);
            let ctx = test_scenario::ctx(scenario);

            interest_engine::generate_coupon_schedule(
                &mut engine,
                1704067200,
                1735603200,
                std::string::utf8(b"ANNUAL"),
                5000000,
                1000,
                100000,
                0,
                ctx,
            );

            let total = interest_engine::get_estimated_total_interest(&engine);
            assert!(total > 0, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }
}
