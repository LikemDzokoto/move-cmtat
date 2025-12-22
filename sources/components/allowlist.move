/// Allowlist Component - KYC/AML Compliance
/// Manages approved addresses for token transfers
module move_cmtat::allowlist {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::table::{Self, Table};

    /// Errors
    const ENotAllowlisted: u64 = 300;
    const EAllowlistNotEnabled: u64 = 301;

    /// Allowlist state
    public struct AllowlistState has key, store {
        id: UID,
        enabled: bool,
        allowlisted: Table<address, bool>,
    }

    /// Initialize allowlist state
    public fun init_allowlist_state(ctx: &mut TxContext): AllowlistState {
        AllowlistState {
            id: object::new(ctx),
            enabled: false,
            allowlisted: table::new(ctx),
        }
    }

    /// Check if allowlist is enabled
    public fun is_enabled(state: &AllowlistState): bool {
        state.enabled
    }

    /// Enable/disable allowlist
    public fun set_enabled(state: &mut AllowlistState, enabled: bool) {
        state.enabled = enabled;
    }

    /// Check if address is allowlisted
    public fun is_allowlisted(state: &AllowlistState, account: address): bool {
        if (!state.enabled) {
            return true  // If allowlist is disabled, all addresses are allowed
        };
        
        if (table::contains(&state.allowlisted, account)) {
            *table::borrow(&state.allowlisted, account)
        } else {
            false
        }
    }

    /// Set address allowlist status
    public fun set_address_allowlist(state: &mut AllowlistState, account: address, status: bool) {
        if (table::contains(&state.allowlisted, account)) {
            let allowlist_status = table::borrow_mut(&mut state.allowlisted, account);
            *allowlist_status = status;
        } else {
            table::add(&mut state.allowlisted, account, status);
        }
    }

    /// Batch set addresses allowlist
    public fun batch_set_address_allowlist(
        state: &mut AllowlistState,
        accounts: vector<address>,
        statuses: vector<bool>
    ) {
        let i = 0;
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), 0);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);
            set_address_allowlist(state, account, status);
            i = i + 1;
        }
    }

    /// Require address to be allowlisted
    public fun require_allowlisted(state: &AllowlistState, account: address) {
        if (state.enabled) {
            assert!(is_allowlisted(state, account), ENotAllowlisted);
        }
    }

    /// Require both sender and receiver to be allowlisted
    public fun require_both_allowlisted(state: &AllowlistState, from: address, to: address) {
        if (state.enabled) {
            assert!(is_allowlisted(state, from), ENotAllowlisted);
            assert!(is_allowlisted(state, to), ENotAllowlisted);
        }
    }
}
