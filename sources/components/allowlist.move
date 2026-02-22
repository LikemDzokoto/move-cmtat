/// Allowlist Component - Address Allowlisting
module move_cmtat::allowlist {
    use iota::table::{Self, Table};

    /// Errors
    const ENotAllowlisted: u64 = 300;

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
            return true  // If disabled, everyone is allowed
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

    /// Batch set allowlist status
    public fun batch_set_address_allowlist(
        state: &mut AllowlistState,
        accounts: vector<address>,
        statuses: vector<bool>
    ) {
        let mut i = 0;
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), 0);

        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);
            set_address_allowlist(state, account, status);
            i = i + 1;
        }
    }

    /// Require address is allowlisted
    public fun require_allowlisted(state: &AllowlistState, account: address) {
        assert!(is_allowlisted(state, account), ENotAllowlisted);
    }

    /// Get count of allowlisted addresses
    public fun get_count(state: &AllowlistState): u64 {
        table::length(&state.allowlisted)
    }

    /// Remove address from allowlist
    public fun remove_address(state: &mut AllowlistState, account: address) {
        if (table::contains(&state.allowlisted, account)) {
            table::remove(&mut state.allowlisted, account);
        };
    }

    /// Batch remove addresses from allowlist
    public fun batch_remove_addresses(
        state: &mut AllowlistState,
        accounts: vector<address>
    ) {
        let len = vector::length(&accounts);
        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            if (table::contains(&state.allowlisted, account)) {
                table::remove(&mut state.allowlisted, account);
            };
            i = i + 1;
        }
    }

    /// Clear all addresses from allowlist (caller provides addresses to remove)
    public fun clear_all(
        state: &mut AllowlistState,
        accounts: vector<address>
    ) {
        let len = vector::length(&accounts);
        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            if (table::contains(&state.allowlisted, account)) {
                table::remove(&mut state.allowlisted, account);
            };
            i = i + 1;
        }
    }
}
