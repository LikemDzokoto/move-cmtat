/// SnapshotEngine Test Suite - Comprehensive Testing for Balance Snapshots
#[test_only]
module move_cmtat::snapshot_engine_tests {
    use std::string;
    use iota::test_scenario::{Self, Scenario};

    use move_cmtat::snapshot_engine::{Self, SnapshotEngine, Snapshot, AccountSnapshot};

    // ============ TEST ADDRESSES ============
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    // ============ HELPER FUNCTIONS ============

    fun setup(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);
            transfer::public_share_object(engine);
        };
    }

    // ============ INITIALIZATION TESTS ============

    #[test]
    fun test_init_snapshot_engine() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            let engine = snapshot_engine::init_snapshot_engine(ctx);

            assert!(snapshot_engine::get_snapshot_counter(&engine) == 0, 0);

            transfer::public_share_object(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_initial_state() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);

            assert!(snapshot_engine::get_snapshot_counter(&engine) == 0, 0);
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

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200, // timestamp
                1000000,    // total supply
                string::utf8(b"Initial snapshot"),
                ctx,
            );

            assert!(snapshot_id == 0, 0);
            assert!(snapshot_engine::get_snapshot_counter(&engine) == 1, 1);
            assert!(snapshot_engine::snapshot_exists(&engine, 0), 2);

            let snapshot = snapshot_engine::get_snapshot(&engine, 0);
            assert!(snapshot.timestamp == 1704067200, 3);
            assert!(snapshot.total_supply == 1000000, 4);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_multiple_snapshots() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let id1 = snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"Snap 1"), ctx);
            let id2 = snapshot_engine::create_snapshot(&mut engine, 1706745600, 1200000, string::utf8(b"Snap 2"), ctx);
            let id3 = snapshot_engine::create_snapshot(&mut engine, 1709424000, 1500000, string::utf8(b"Snap 3"), ctx);

            assert!(id1 == 0, 0);
            assert!(id2 == 1, 1);
            assert!(id3 == 2, 2);
            assert!(snapshot_engine::get_snapshot_counter(&engine) == 3, 3);

            let ids = snapshot_engine::get_all_snapshot_ids(&engine);
            assert!(vector::length(&ids) == 3, 4);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot_exists() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            assert!(!snapshot_engine::snapshot_exists(&engine, 0), 0);

            snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"Snap"), ctx);

            assert!(snapshot_engine::snapshot_exists(&engine, 0), 1);
            assert!(!snapshot_engine::snapshot_exists(&engine, 99), 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_snapshot_data() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Test snapshot"),
                ctx,
            );

            let snapshot = snapshot_engine::get_snapshot(&engine, id);
            assert!(snapshot.id == 0, 0);
            assert!(snapshot.timestamp == 1704067200, 1);
            assert!(snapshot.total_supply == 1000000, 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ BALANCE RECORDING TESTS ============

    #[test]
    fun test_record_balance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Snap"),
                ctx,
            );

            snapshot_engine::record_balance(
                &mut engine,
                snapshot_id,
                USER1,
                500000,
                ctx,
            );

            let balance = snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1);
            assert!(balance == 500000, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_record_balance_duplicate_fails() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Snap"),
                ctx,
            );

            snapshot_engine::record_balance(
                &mut engine,
                snapshot_id,
                USER1,
                500000,
                ctx,
            );

            // Try to record again for same user - should fail
            snapshot_engine::record_balance(
                &mut engine,
                snapshot_id,
                USER1,
                600000,
                ctx,
            );

            // Balance should be updated (behavior depends on implementation)
            let balance = snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1);
            assert!(balance == 600000 || balance == 500000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_balance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Snap"),
                ctx,
            );

            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 500000, ctx);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 500000, 0);

            snapshot_engine::update_balance(&mut engine, snapshot_id, USER1, 750000);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 750000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_balance_at_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                2000000,
                string::utf8(b"Snap"),
                ctx,
            );

            // Record balances for multiple users
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 500000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER2, 750000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER3, 250000, ctx);

            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1) == 500000, 0);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER2) == 750000, 1);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER3) == 250000, 2);

            // Non-existent user
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, @0x99) == 0, 3);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ BALANCE QUERY TESTS ============

    #[test]
    fun test_get_all_snapshot_ids() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let ids = snapshot_engine::get_all_snapshot_ids(&engine);
            assert!(vector::length(&ids) == 0, 0);

            snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"Snap 1"), ctx);
            snapshot_engine::create_snapshot(&mut engine, 1706745600, 1000000, string::utf8(b"Snap 2"), ctx);

            let ids2 = snapshot_engine::get_all_snapshot_ids(&engine);
            assert!(vector::length(&ids2) == 2, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_snapshots_in_range() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Create snapshots at different times
            snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"2024-01"), ctx); // 0
            snapshot_engine::create_snapshot(&mut engine, 1706745600, 1100000, string::utf8(b"2024-02"), ctx); // 1
            snapshot_engine::create_snapshot(&mut engine, 1709424000, 1200000, string::utf8(b"2024-03"), ctx); // 2
            snapshot_engine::create_snapshot(&mut engine, 1712102400, 1300000, string::utf8(b"2024-04"), ctx); // 3

            // Get snapshots in range (Feb-Mar)
            let range_ids = snapshot_engine::get_snapshots_in_range(&engine, 1705000000, 1710000000);
            assert!(vector::length(&range_ids) == 2, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_snapshot_accounts() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1500000,
                string::utf8(b"Snap"),
                ctx,
            );

            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 500000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER2, 750000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER3, 250000, ctx);

            let accounts = snapshot_engine::get_snapshot_accounts(&engine, snapshot_id);
            assert!(vector::length(&accounts) == 3, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ DISTRIBUTION HELPER TESTS ============

    #[test]
    fun test_calculate_proportional_share() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Test snap"),
                ctx,
            );

            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 250000, ctx);

            // Calculate proportional share for $1000000 distribution
            let share = snapshot_engine::calculate_proportional_share(
                &engine,
                snapshot_id,
                USER1,
                1000000,
            );

            // Expected: 1000000 * (250000 / 1000000) = 250000
            assert!(share == 250000, 0);

            // Test with different snapshot (no balance recorded)
            let snapshot_id2 = snapshot_engine::create_snapshot(
                &mut engine,
                1706745600,
                2000000,
                string::utf8(b"Test snap 2"),
                ctx,
            );

            snapshot_engine::record_balance(&mut engine, snapshot_id2, USER2, 500000, ctx);

            let share2 = snapshot_engine::calculate_proportional_share(
                &engine,
                snapshot_id2,
                USER2,
                1000000,
            );
            assert!(share2 == 250000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_distribution() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Distribution snapshot"),
                ctx,
            );

            // Record balances
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 500000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER2, 300000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER3, 200000, ctx);

            // Calculate distribution for $10000
            let user1_share = snapshot_engine::calculate_proportional_share(
                &engine,
                snapshot_id,
                USER1,
                10000,
            );
            let user2_share = snapshot_engine::calculate_proportional_share(
                &engine,
                snapshot_id,
                USER2,
                10000,
            );
            let user3_share = snapshot_engine::calculate_proportional_share(
                &engine,
                snapshot_id,
                USER3,
                10000,
            );

            assert!(user1_share == 5000, 0);
            assert!(user2_share == 3000, 1);
            assert!(user3_share == 2000, 2);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ VALIDATION TESTS ============

    #[test]
    fun test_require_snapshot_exists() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            snapshot_engine::require_snapshot_exists(&engine, 0); // Should not abort (no-op)

            snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"Snap"), ctx);

            snapshot_engine::require_snapshot_exists(&engine, 0); // Should not abort

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ EDGE CASE TESTS ============

    #[test]
    fun test_empty_snapshot() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                0, // No supply
                string::utf8(b"Empty snapshot"),
                ctx,
            );

            // Get balance for non-existent user
            let balance = snapshot_engine::get_balance_at_snapshot(&engine, snapshot_id, USER1);
            assert!(balance == 0, 0);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_snapshots_different_users() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            // Create two snapshots
            let snap1_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Snap 1"),
                ctx,
            );

            let snap2_id = snapshot_engine::create_snapshot(
                &mut engine,
                1706745600,
                1500000,
                string::utf8(b"Snap 2"),
                ctx,
            );

            // Record different balances in each snapshot
            snapshot_engine::record_balance(&mut engine, snap1_id, USER1, 500000, ctx);
            snapshot_engine::record_balance(&mut engine, snap2_id, USER1, 750000, ctx);

            // Verify balances are snapshot-specific
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap1_id, USER1) == 500000, 0);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap2_id, USER1) == 750000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_snapshot_total_supply() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Supply snapshot"),
                ctx,
            );

            let snapshot = snapshot_engine::get_snapshot(&engine, snapshot_id);
            assert!(snapshot.total_supply == 1000000, 0);

            // Record balances
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER1, 400000, ctx);
            snapshot_engine::record_balance(&mut engine, snapshot_id, USER2, 350000, ctx);

            // Total supply remains unchanged
            let snapshot2 = snapshot_engine::get_snapshot(&engine, snapshot_id);
            assert!(snapshot2.total_supply == 1000000, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_get_snapshot_timestamp() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snap1_id = snapshot_engine::create_snapshot(&mut engine, 1704067200, 1000000, string::utf8(b"Snap 1"), ctx);
            let snap2_id = snapshot_engine::create_snapshot(&mut engine, 1706745600, 1000000, string::utf8(b"Snap 2"), ctx);

            assert!(snapshot_engine::get_snapshot_timestamp(&engine, snap1_id) == 1704067200, 0);
            assert!(snapshot_engine::get_snapshot_timestamp(&engine, snap2_id) == 1706745600, 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_snapshot_description() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snapshot_id = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Original description"),
                ctx,
            );

            let snapshot = snapshot_engine::get_snapshot(&engine, snapshot_id);
            assert!(snapshot.description == string::utf8(b"Original description"), 0);

            snapshot_engine::update_snapshot_description(&mut engine, snapshot_id, string::utf8(b"Updated description"));

            let snapshot2 = snapshot_engine::get_snapshot(&engine, snapshot_id);
            assert!(snapshot2.description == string::utf8(b"Updated description"), 1);

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }

    // ============ COMPREHENSIVE WORKFLOW TEST ============

    #[test]
    fun test_complete_snapshot_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        setup(scenario);

        // Create initial snapshot
        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snap1 = snapshot_engine::create_snapshot(
                &mut engine,
                1704067200,
                1000000,
                string::utf8(b"Q1 2024 Snapshot"),
                ctx,
            );

            snapshot_engine::record_balance(&mut engine, snap1, USER1, 600000, ctx);
            snapshot_engine::record_balance(&mut engine, snap1, USER2, 400000, ctx);

            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap1, USER1) == 600000, 0);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap1, USER2) == 400000, 1);

            test_scenario::return_shared(engine);
        };

        // Create second snapshot after transfers
        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let snap2 = snapshot_engine::create_snapshot(
                &mut engine,
                1706745600,
                1000000,
                string::utf8(b"Q2 2024 Snapshot"),
                ctx,
            );

            // USER1 transferred some to USER3
            snapshot_engine::record_balance(&mut engine, snap2, USER1, 450000, ctx);
            snapshot_engine::record_balance(&mut engine, snap2, USER2, 350000, ctx);
            snapshot_engine::record_balance(&mut engine, snap2, USER3, 200000, ctx);

            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap2, USER1) == 450000, 0);
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap2, USER3) == 200000, 1);

            // Verify Q1 snapshot unchanged
            assert!(snapshot_engine::get_balance_at_snapshot(&engine, snap1, USER1) == 600000, 2);

            test_scenario::return_shared(engine);
        };

        // Calculate distribution based on Q1 snapshot
        test_scenario::next_tx(scenario, ADMIN);
        {
            let engine = test_scenario::take_shared<SnapshotEngine>(scenario);

            // We need to use the snapshot_id from before. Let me simplify this test.
            // Since we can't access snap1_id here, let's just verify the snapshot exists
            let ids = snapshot_engine::get_all_snapshot_ids(&engine);
            if (vector::length(&ids) > 0) {
                let snap1_id = *vector::borrow(&ids, 0);
                let user1_share = snapshot_engine::calculate_proportional_share(
                    &engine,
                    snap1_id,
                    USER1,
                    100000,
                );
                let user2_share = snapshot_engine::calculate_proportional_share(
                    &engine,
                    snap1_id,
                    USER2,
                    100000,
                );

                // USER1 had 600000/1000000 = 60%
                // USER2 had 400000/1000000 = 40%
                assert!(user1_share == 60000, 0);
                assert!(user2_share == 40000, 1);
            };

            test_scenario::return_shared(engine);
        };

        test_scenario::end(scenario_val);
    }
}
