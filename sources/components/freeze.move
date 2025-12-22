/// Freeze Component - Address Freezing and Partial Token Freezing
/// Allows enforcement of regulatory compliance by freezing addresses
module move_cmtat::freeze {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::table::{Self, Table};

    /// Errors
    const EFrozenAddress: u64 = 200;
    const EInsufficientActiveBalance: u64 = 201;

    /// Freeze state tracking
    public struct FreezeState has key, store {
        id: UID,
        frozen_addresses: Table<address, bool>,
        frozen_tokens: Table<address, u64>,  // Amount of frozen tokens per address
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
    public fun is_frozen(state: &FreezeState, account: address): bool {
        if (table::contains(&state.frozen_addresses, account)) {
            *table::borrow(&state.frozen_addresses, account)
        } else {
            false
        }
    }

    /// Set address frozen status
    public fun set_address_frozen(state: &mut FreezeState, account: address, frozen: bool) {
        if (table::contains(&state.frozen_addresses, account)) {
            let status = table::borrow_mut(&mut state.frozen_addresses, account);
            *status = frozen;
        } else {
            table::add(&mut state.frozen_addresses, account, frozen);
        }
    }

    /// Batch set addresses frozen
    public fun batch_set_address_frozen(
        state: &mut FreezeState,
        accounts: vector<address>,
        statuses: vector<bool>
    ) {
        let i = 0;
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
    public fun get_frozen_amount(state: &FreezeState, account: address): u64 {
        if (table::contains(&state.frozen_tokens, account)) {
            *table::borrow(&state.frozen_tokens, account)
        } else {
            0
        }
    }

    /// Freeze partial tokens (for allowlist module)
    public fun freeze_partial_tokens(state: &mut FreezeState, account: address, amount: u64) {
        if (table::contains(&state.frozen_tokens, account)) {
            let frozen = table::borrow_mut(&mut state.frozen_tokens, account);
            *frozen = *frozen + amount;
        } else {
            table::add(&mut state.frozen_tokens, account, amount);
        }
    }

    /// Unfreeze partial tokens
    public fun unfreeze_partial_tokens(state: &mut FreezeState, account: address, amount: u64) {
        if (table::contains(&state.frozen_tokens, account)) {
            let frozen = table::borrow_mut(&mut state.frozen_tokens, account);
            assert!(*frozen >= amount, EInsufficientActiveBalance);
            *frozen = *frozen - amount;
        }
    }

    /// Get active balance (total balance - frozen amount)
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
