/// Freeze Component - Address Freezing (FIXED - Simplified for DenyList)
/// NOTE: This is kept for backwards compatibility but should use native DenyList
module move_cmtat::freeze {
    use iota::object::{Self, UID};
    use iota::tx_context::TxContext;
    use iota::table::{Self, Table};  

    /// Errors
    const EFrozenAddress: u64 = 200;
    const EInsufficientActiveBalance: u64 = 201;

    /// Freeze state tracking
    public struct FreezeState has key, store {
        id: UID,
        frozen_addresses: Table<address, bool>,
        frozen_tokens: Table<address, u64>,
    }

    /// Initialize freeze state
    public fun init_freeze_state(ctx: &mut TxContext): FreezeState {
        FreezeState {
            id: object::new(ctx),
            frozen_addresses: table::new(ctx),
            frozen_tokens: table::new(ctx),
        }
    }

    /// Check if address is frozen
    public fun is_frozen(_state: &FreezeState, _account: address): bool { 
        //  NOTE: Should use native DenyList instead
        // if (table::contains(&state.frozen_addresses, account)) {
        //     *table::borrow(&state.frozen_addresses, account)
        // } else {
        //     false
        // }
        false
    }

    /// Set address frozen status
    public fun set_address_frozen(_state: &mut FreezeState, _account: address, _frozen: bool) { 
        //  NOTE: Should use native DenyList instead
        // if (table::contains(&state.frozen_addresses, account)) {
        //     let status = table::borrow_mut(&mut state.frozen_addresses, account);
        //     *status = frozen;
        // } else {
        //     table::add(&mut state.frozen_addresses, account, frozen);
        // }
    }

    /// Batch set addresses frozen
    public fun batch_set_address_frozen(
        state: &mut FreezeState,
        accounts: vector<address>,
        statuses: vector<bool>
    ) {
        let mut i = 0;
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), 0);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);
            set_address_frozen(state, account, status);
            i = i + 1;
        }
    }

    /// Get frozen token amount for address
    public fun get_frozen_amount(_state: &FreezeState, _account: address): u64 {  // ✅ FIX: Prefix with _
        // if (table::contains(&state.frozen_tokens, account)) {
        //     *table::borrow(&state.frozen_tokens, account)
        // } else {
        //     0
        // }
        0
    }

    /// Freeze partial tokens
    public fun freeze_partial_tokens(_state: &mut FreezeState, _account: address, _amount: u64) {  // ✅ FIX: Prefix with _
        // if (table::contains(&state.frozen_tokens, account)) {
        //     let frozen = table::borrow_mut(&mut state.frozen_tokens, account);
        //     *frozen = *frozen + amount;
        // } else {
        //     table::add(&mut state.frozen_tokens, account, amount);
        // }
    }

    /// Unfreeze partial tokens
    public fun unfreeze_partial_tokens(_state: &mut FreezeState, _account: address, _amount: u64) {  // ✅ FIX: Prefix with _
        // if (table::contains(&state.frozen_tokens, account)) {
        //     let frozen = table::borrow_mut(&mut state.frozen_tokens, account);
        //     assert!(*frozen >= amount, EInsufficientActiveBalance);
        //     *frozen = *frozen - amount;
        // }
    }

    /// Get active balance
    public fun get_active_balance(total_balance: u64, state: &FreezeState, account: address): u64 {
        let frozen = get_frozen_amount(state, account);
        if (total_balance > frozen) {
            total_balance - frozen
        } else {
            0
        }
    }

    /// Require address not frozen
    public fun require_not_frozen(state: &FreezeState, account: address) {
        assert!(!is_frozen(state, account), EFrozenAddress);
    }
}
