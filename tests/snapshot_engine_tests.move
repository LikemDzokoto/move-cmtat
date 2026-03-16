/// SnapshotEngine Test Suite - Tests for balance snapshot functionality
#[test_only]
#[allow(unused_use, unused_function, unused_const, duplicate_alias)]
module move_cmtat::snapshot_engine_tests {
    use iota::test_scenario::{Self, Scenario};
    use std::vector;

    use move_cmtat::snapshot_engine::{Self, SnapshotEngine, Snapshot};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_snapshot_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);

            assert!(snapshot_engine::get_snapshot_count(&engine) == 0, 0);

            transfer::public_share_object(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_initial_state() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);

            assert!(snapshot_engine::get_snapshot_count(&engine) == 0, 0);
            assert!(snapshot_engine::get_all_snapshot_ids(&engine) == vector[], 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ SNAPSHOT CREATION TESTS ============

    #[test]
    fun test_create_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1000000,
                1704067200,
                ctx,
            );

            assert!(snapshot_id == 0, 0);
            assert!(snapshot_engine::get_snapshot_count(&engine) == 1, 1);
            assert!(snapshot_engine::snapshot_exists(&engine, 0), 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_snapshot_with_description() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot_with_description(
                &mut engine,
                1000000,
                1704067200,
                b"Initial snapshot",
                ctx,
            );

            assert!(snapshot_id == 0, 0);

            let _snapshot = snapshot_engine::get_snapshot_full(&engine, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_multiple_snapshots() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let id1 = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);
            let id2 = snapshot_engine::create_snapshot(&mut engine, 1200000, 1706745600, ctx);
            let id3 = snapshot_engine::create_snapshot(&mut engine, 1500000, 1709424000, ctx);

            assert!(id1 == 0, 0);
            assert!(id2 == 1, 1);
            assert!(id3 == 2, 2);
            assert!(snapshot_engine::get_snapshot_count(&engine) == 3, 3);

            let ids = snapshot_engine::get_all_snapshot_ids(&engine);
            assert!(vector::length(&ids) == 3, 4);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ BALANCE RECORDING TESTS ============

    #[test]
    fun test_record_balance_at_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 500000, ctx);

            let balance = snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1);
            assert!(balance == 500000, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_record_balance_update() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 500000, ctx);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 500000, 0);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 750000, ctx);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 750000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_balance_at_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 2000000, 1704067200, ctx);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 500000, ctx);
            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER2, 750000, ctx);
            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER3, 250000, ctx);

            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 500000, 0);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER2) == 750000, 1);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER3) == 250000, 2);

            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, @0x99) == 0, 3);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ BALANCE QUERY TESTS ============

    #[test]
    fun test_has_balance_at_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            assert!(!snapshot_engine::has_balance_at_snapshot(&engine, snapshot_id, USER1), 0);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 500000, ctx);

            assert!(snapshot_engine::has_balance_at_snapshot(&engine, snapshot_id, USER1), 1);
            assert!(!snapshot_engine::has_balance_at_snapshot(&engine, snapshot_id, @0x99), 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ DISTRIBUTION HELPER TESTS ============

    #[test]
    fun test_calculate_proportional_share() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 250000, ctx);

            let share = snapshot_engine::calculate_proportional_share(&engine, snapshot_id, USER1, 1000000);
            assert!(share == 250000, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_require_snapshot_exists() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            snapshot_engine::require_snapshot_exists(&engine, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_empty_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 0, 1704067200, ctx);

            let balance = snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1);
            assert!(balance == 0, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_latest_snapshot_id() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(snapshot_engine::get_latest_snapshot_id(&engine) == 0, 0);

            snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);
            snapshot_engine::create_snapshot(&mut engine, 1000000, 1706745600, ctx);
            snapshot_engine::create_snapshot(&mut engine, 1000000, 1709424000, ctx);

            assert!(snapshot_engine::get_latest_snapshot_id(&engine) == 2, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot_total_supply() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            let total_supply = snapshot_engine::get_total_supply_at(&engine, snapshot_id);
            assert!(total_supply == 1000000, 0);

            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER1, 400000, ctx);
            snapshot_engine::record_balance_at_snapshot(&mut engine, snapshot_id, USER2, 350000, ctx);

            let total_supply2 = snapshot_engine::get_total_supply_at(&engine, snapshot_id);
            assert!(total_supply2 == 1000000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_mark_snapshot_complete() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(&mut engine, 1000000, 1704067200, ctx);

            assert!(!snapshot_engine::is_snapshot_completed(&engine, snapshot_id), 0);

            snapshot_engine::mark_snapshot_complete(&mut engine, snapshot_id);

            assert!(snapshot_engine::is_snapshot_completed(&engine, snapshot_id), 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }
}
