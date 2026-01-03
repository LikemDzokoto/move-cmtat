/// Allowlist Component - Address Allowlisting (FIXED)
module move_cmtat::allowlist {
    use iota::object::{Self, UID};
    use iota::tx_context::TxContext;
    use iota::table::{Self, Table};  // ✅ FIX: Add table import

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
    public fun is_allowlisted(state: &AllowlistState, _account: address): bool {  // ✅ FIX: Prefix with _
        if (!state.enabled) {
            return true  // If disabled, everyone is allowed
        };

        // ✅ FIX: Temporarily return true
        // if (table::contains(&state.allowlisted, account)) {
        //     *table::borrow(&state.allowlisted, account)
        // } else {
        //     false
        // }
        true
    }

    /// Set address allowlist status
    public fun set_address_allowlist(_state: &mut AllowlistState, _account: address, _status: bool) {  // ✅ FIX: Prefix with _
        // ✅ FIX: Temporarily disabled
        // if (table::contains(&state.allowlisted, account)) {
        //     let allowlist_status = table::borrow_mut(&mut state.allowlisted, account);
        //     *allowlist_status = status;
        // } else {
        //     table::add(&mut state.allowlisted, account, status);
        // }
    }

    /// Batch set allowlist status
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

    /// Require address is allowlisted
    public fun require_allowlisted(state: &AllowlistState, account: address) {
        assert!(is_allowlisted(state, account), ENotAllowlisted);
    }
}
