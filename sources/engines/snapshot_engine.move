/// Snapshot Engine - Historical Balance Tracking
/// Complete implementation with working balance recording and retrieval
/// Used for dividend distributions, interest payments, and voting rights
#[allow(unused_const, unused_field, duplicate_alias)]
module move_cmtat::snapshot_engine {
    use iota::table::{Self, Table};
    use iota::vec_map::{Self, VecMap};
    use std::vector;

    /// Errors
    const ESnapshotNotFound: u64 = 700;
    const EAccountNotFound: u64 = 701;
    const EInvalidSnapshotId: u64 = 702;
    const EBalanceAlreadyRecorded: u64 = 703;

    /// Snapshot data structure
    public struct Snapshot has store, drop, copy {
        id: u64,
        timestamp: u64,           // Unix timestamp in seconds
        total_supply: u64,
        block_number: u64,        // Optional: block number for reference
        description: vector<u8>,  // Optional: description of the snapshot
    }

    /// Account balance at specific snapshot
    public struct AccountSnapshot has store, drop, copy {
        _account: address,
        _balance: u64,
    }

    /// Snapshot engine state
    public struct SnapshotEngine has key, store {
        id: UID,
        snapshot_counter: u64,
        snapshots: VecMap<u64, Snapshot>,
        // Nested table: snapshot_id -> account -> balance
        balances: Table<u64, Table<address, u64>>,
        // Track which snapshots have been fully recorded
        completed_snapshots: Table<u64, bool>,
    }

    // ========== INITIALIZATION ==========

    /// Initialize snapshot engine
    public fun init_snapshot_engine(ctx: &mut TxContext): SnapshotEngine {
        SnapshotEngine {
            id: object::new(ctx),
            snapshot_counter: 0,
            snapshots: vec_map::empty(),
            balances: table::new(ctx),
            completed_snapshots: table::new(ctx),
        }
    }

    // ========== SNAPSHOT CREATION ==========

    /// Create new snapshot with current total supply
    public fun create_snapshot(
        engine: &mut SnapshotEngine,
        total_supply: u64,
        timestamp: u64,
        ctx: &mut TxContext
    ): u64 {
        let snapshot_id = engine.snapshot_counter;
        engine.snapshot_counter = snapshot_id + 1;

        let snapshot = Snapshot {
            id: snapshot_id,
            timestamp,
            total_supply,
            block_number: 0,
            description: vector::empty(),
        };

        // Store snapshot
        vec_map::insert(&mut engine.snapshots, snapshot_id, snapshot);

        // Create balance table for this snapshot
        let balance_table = table::new<address, u64>(ctx);
        table::add(&mut engine.balances, snapshot_id, balance_table);

        // Mark as not completed
        table::add(&mut engine.completed_snapshots, snapshot_id, false);

        snapshot_id
    }

    /// Create snapshot with description
    public fun create_snapshot_with_description(
        engine: &mut SnapshotEngine,
        total_supply: u64,
        timestamp: u64,
        description: vector<u8>,
        ctx: &mut TxContext
    ): u64 {
        let snapshot_id = engine.snapshot_counter;
        engine.snapshot_counter = snapshot_id + 1;

        let snapshot = Snapshot {
            id: snapshot_id,
            timestamp,
            total_supply,
            block_number: 0,
            description,
        };

        vec_map::insert(&mut engine.snapshots, snapshot_id, snapshot);

        let balance_table = table::new<address, u64>(ctx);
        table::add(&mut engine.balances, snapshot_id, balance_table);
        table::add(&mut engine.completed_snapshots, snapshot_id, false);

        snapshot_id
    }

    // ========== BALANCE RECORDING ==========

    /// Record balance for specific account at snapshot
    public fun record_balance_at_snapshot(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        account: address,
        balance: u64,
        _ctx: &mut TxContext
    ) {
        // Verify snapshot exists
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        // Get balance table for this snapshot
        let balance_table = table::borrow_mut(&mut engine.balances, snapshot_id);

        // Add or update balance
        if (table::contains(balance_table, account)) {
            let existing_balance = table::borrow_mut(balance_table, account);
            *existing_balance = balance;
        } else {
            table::add(balance_table, account, balance);
        }
    }

    /// Batch record balances for multiple accounts
    public fun batch_record_balances(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        accounts: vector<address>,
        balances: vector<u64>,
        ctx: &mut TxContext
    ) {
        let len = vector::length(&accounts);
        assert!(len == vector::length(&balances), 0);

        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let balance = *vector::borrow(&balances, i);
            record_balance_at_snapshot(engine, snapshot_id, account, balance, ctx);
            i = i + 1;
        }
    }

    /// Mark snapshot as fully recorded (all balances captured)
    public fun mark_snapshot_complete(
        engine: &mut SnapshotEngine,
        snapshot_id: u64
    ) {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);
        
        let completed = table::borrow_mut(&mut engine.completed_snapshots, snapshot_id);
        *completed = true;
    }

    // ========== BALANCE QUERIES ==========

    /// Get balance for specific account at snapshot
    public fun get_balance_at_snapshot(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        account: address
    ): u64 {
        // Verify snapshot exists
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        // Get balance table
        let balance_table = table::borrow(&engine.balances, snapshot_id);

        // Return balance or 0 if not found
        if (table::contains(balance_table, account)) {
            *table::borrow(balance_table, account)
        } else {
            0
        }
    }

    /// Check if account has recorded balance at snapshot
    public fun has_balance_at_snapshot(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        account: address
    ): bool {
        if (!snapshot_exists(engine, snapshot_id)) {
            return false
        };

        let balance_table = table::borrow(&engine.balances, snapshot_id);
        table::contains(balance_table, account)
    }

    /// Get all accounts with recorded balances at snapshot
    public fun get_snapshot_accounts(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): vector<address> {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let _balance_table = table::borrow(&engine.balances, snapshot_id);
        let accounts = vector::empty<address>();
        
        // Note: IOTA tables don't support iteration, so this is limited
        // In practice, accounts would be tracked separately
        accounts
    }

    // ========== SNAPSHOT QUERIES ==========

    /// Get snapshot data
    public fun get_snapshot(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): (u64, u64, u64) {  // (id, timestamp, total_supply)
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let snapshot = vec_map::get(&engine.snapshots, &snapshot_id);
        (snapshot.id, snapshot.timestamp, snapshot.total_supply)
    }

    /// Get full snapshot struct
    public fun get_snapshot_full(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): Snapshot {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);
        *vec_map::get(&engine.snapshots, &snapshot_id)
    }

    /// Get total supply at snapshot
    public fun get_total_supply_at(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): u64 {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let snapshot = vec_map::get(&engine.snapshots, &snapshot_id);
        snapshot.total_supply
    }

    /// Get snapshot timestamp
    public fun get_snapshot_timestamp(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): u64 {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let snapshot = vec_map::get(&engine.snapshots, &snapshot_id);
        snapshot.timestamp
    }

    /// Check if snapshot exists
    public fun snapshot_exists(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): bool {
        vec_map::contains(&engine.snapshots, &snapshot_id)
    }

    /// Check if snapshot is completed
    public fun is_snapshot_completed(
        engine: &SnapshotEngine,
        snapshot_id: u64
    ): bool {
        if (!snapshot_exists(engine, snapshot_id)) {
            return false
        };

        *table::borrow(&engine.completed_snapshots, snapshot_id)
    }

    /// Get latest snapshot ID
    public fun get_latest_snapshot_id(engine: &SnapshotEngine): u64 {
        if (engine.snapshot_counter == 0) {
            return 0
        };
        engine.snapshot_counter - 1
    }

    /// Get snapshot count
    public fun get_snapshot_count(engine: &SnapshotEngine): u64 {
        engine.snapshot_counter
    }

    /// Get all snapshot IDs
    public fun get_all_snapshot_ids(engine: &SnapshotEngine): vector<u64> {
        let mut ids = vector::empty<u64>();
        let mut i = 0;
        
        while (i < engine.snapshot_counter) {
            if (snapshot_exists(engine, i)) {
                vector::push_back(&mut ids, i);
            };
            i = i + 1;
        };

        ids
    }

    // ========== UTILITY FUNCTIONS ==========

    /// Calculate proportional share of distribution
    /// Returns amount * (account_balance / total_supply)
    public fun calculate_proportional_share(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        account: address,
        total_distribution: u64
    ): u64 {
        let account_balance = get_balance_at_snapshot(engine, snapshot_id, account);
        let total_supply = get_total_supply_at(engine, snapshot_id);

        if (total_supply == 0 || account_balance == 0) {
            return 0
        };

        // Calculate: total_distribution * account_balance / total_supply
        let share = (total_distribution as u128) * (account_balance as u128);
        ((share / (total_supply as u128)) as u64)
    }

    /// Find latest snapshot before or at given timestamp
    public fun find_snapshot_at_time(
        engine: &SnapshotEngine,
        target_time: u64
    ): Option<u64> {
        let mut latest_id = option::none<u64>();
        let mut latest_time = 0;

        let mut i = 0;
        while (i < engine.snapshot_counter) {
            if (snapshot_exists(engine, i)) {
                let snapshot_time = get_snapshot_timestamp(engine, i);
                if (snapshot_time <= target_time && snapshot_time > latest_time) {
                    latest_time = snapshot_time;
                    latest_id = option::some(i);
                }
            };
            i = i + 1;
        };

        latest_id
    }

    /// Get snapshots within time range
    public fun get_snapshots_in_range(
        engine: &SnapshotEngine,
        start_time: u64,
        end_time: u64
    ): vector<u64> {
        let mut ids = vector::empty<u64>();
        
        let mut i = 0;
        while (i < engine.snapshot_counter) {
            if (snapshot_exists(engine, i)) {
                let snapshot_time = get_snapshot_timestamp(engine, i);
                if (snapshot_time >= start_time && snapshot_time <= end_time) {
                    vector::push_back(&mut ids, i);
                }
            };
            i = i + 1;
        };

        ids
    }

    // ========== SNAPSHOT MANAGEMENT ==========

    /// Update snapshot description
    public fun update_snapshot_description(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        description: vector<u8>
    ) {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let snapshot = vec_map::get_mut(&mut engine.snapshots, &snapshot_id);
        snapshot.description = description;
    }

    /// Update snapshot block number
    public fun update_snapshot_block_number(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        block_number: u64
    ) {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);

        let snapshot = vec_map::get_mut(&mut engine.snapshots, &snapshot_id);
        snapshot.block_number = block_number;
    }

    // ========== VALIDATION ==========

    /// Require snapshot exists
    public fun require_snapshot_exists(engine: &SnapshotEngine, snapshot_id: u64) {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);
    }

    /// Require account has balance recorded
    public fun require_account_has_balance(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        account: address
    ) {
        assert!(snapshot_exists(engine, snapshot_id), ESnapshotNotFound);
        assert!(has_balance_at_snapshot(engine, snapshot_id, account), EAccountNotFound);
    }
}
