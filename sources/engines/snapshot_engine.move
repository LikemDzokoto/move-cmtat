/// Snapshot Engine - Balance Snapshots
/// Provides historical balance tracking for compliance and reporting
module move_cmtat::snapshot_engine {
    use iota::object::{Self, UID};
    use iota::tx_context::TxContext;
    use iota::table::{Self, Table};
    use iota::vec_map::{Self, VecMap};

    /// Errors
    const ESnapshotNotFound: u64 = 700;
    const EInvalidSnapshotId: u64 = 701;

    /// Snapshot data structure
    public struct Snapshot has store, copy, drop {
        snapshot_id: u64,
        timestamp: u64,
        total_supply: u64,
    }

    /// Snapshot engine state
    public struct SnapshotEngine has key, store {
        id: UID,
        current_snapshot_id: u64,
        snapshots: VecMap<u64, Snapshot>,  // snapshot_id -> Snapshot
        balances: Table<u64, Table<address, u64>>,  // snapshot_id -> (address -> balance)
    }

    /// Initialize snapshot engine
    public fun init_snapshot_engine(ctx: &mut TxContext): SnapshotEngine {
        SnapshotEngine {
            id: object::new(ctx),
            current_snapshot_id: 0,
            snapshots: vec_map::empty(),
            balances: table::new(ctx),
        }
    }

    /// Create a new snapshot
    public fun create_snapshot(
        engine: &mut SnapshotEngine,
        total_supply: u64,
        timestamp: u64,
        ctx: &mut TxContext
    ): u64 {
        let snapshot_id = engine.current_snapshot_id + 1;
        engine.current_snapshot_id = snapshot_id;

        let snapshot = Snapshot {
            snapshot_id,
            timestamp,
            total_supply,
        };

        vec_map::insert(&mut engine.snapshots, snapshot_id, snapshot);
        
        // Initialize empty balance table for this snapshot
        table::add(&mut engine.balances, snapshot_id, table::new(ctx));

        snapshot_id
    }

    /// Record balance in snapshot
    public fun record_balance(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        account: address,
        balance: u64
    ) {
        assert!(snapshot_id <= engine.current_snapshot_id, EInvalidSnapshotId);
        
        let balances = table::borrow_mut(&mut engine.balances, snapshot_id);
        
        if (table::contains(balances, account)) {
            let balance_ref = table::borrow_mut(balances, account);
            *balance_ref = balance;
        } else {
            table::add(balances, account, balance);
        }
    }

    /// Batch record balances in snapshot
    public fun batch_record_balances(
        engine: &mut SnapshotEngine,
        snapshot_id: u64,
        accounts: vector<address>,
        balances_vec: vector<u64>
    ) {
        assert!(snapshot_id <= engine.current_snapshot_id, EInvalidSnapshotId);
        assert!(vector::length(&accounts) == vector::length(&balances_vec), 0);

        let i = 0;
        let len = vector::length(&accounts);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let balance = *vector::borrow(&balances_vec, i);
            record_balance(engine, snapshot_id, account, balance);
            i = i + 1;
        }
    }

    /// Get balance at snapshot
    public fun get_balance_at(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        account: address
    ): u64 {
        assert!(snapshot_id <= engine.current_snapshot_id, EInvalidSnapshotId);
        assert!(table::contains(&engine.balances, snapshot_id), ESnapshotNotFound);
        
        let balances = table::borrow(&engine.balances, snapshot_id);
        
        if (table::contains(balances, account)) {
            *table::borrow(balances, account)
        } else {
            0
        }
    }

    /// Get snapshot info
    public fun get_snapshot(engine: &SnapshotEngine, snapshot_id: u64): (u64, u64, u64) {
        assert!(vec_map::contains(&engine.snapshots, &snapshot_id), ESnapshotNotFound);
        
        let snapshot = vec_map::get(&engine.snapshots, &snapshot_id);
        (snapshot.snapshot_id, snapshot.timestamp, snapshot.total_supply)
    }

    /// Get current snapshot ID
    public fun get_current_snapshot_id(engine: &SnapshotEngine): u64 {
        engine.current_snapshot_id
    }

    /// Get total supply at snapshot
    public fun get_total_supply_at(engine: &SnapshotEngine, snapshot_id: u64): u64 {
        assert!(vec_map::contains(&engine.snapshots, &snapshot_id), ESnapshotNotFound);
        
        let snapshot = vec_map::get(&engine.snapshots, &snapshot_id);
        snapshot.total_supply
    }

    /// Check if snapshot exists
    public fun snapshot_exists(engine: &SnapshotEngine, snapshot_id: u64): bool {
        vec_map::contains(&engine.snapshots, &snapshot_id)
    }

    /// Get batch balances at snapshot
    public fun batch_get_balances_at(
        engine: &SnapshotEngine,
        snapshot_id: u64,
        accounts: vector<address>
    ): vector<u64> {
        assert!(snapshot_id <= engine.current_snapshot_id, EInvalidSnapshotId);
        
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(&accounts);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let balance = get_balance_at(engine, snapshot_id, account);
            vector::push_back(&mut result, balance);
            i = i + 1;
        };
        
        result
    }
}
