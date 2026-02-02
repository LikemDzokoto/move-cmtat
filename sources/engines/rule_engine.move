/// Rule Engine - Simplified for Allowlist-Only Validation
/// Freeze/Pause validation moved to native DenyList
module move_cmtat::rule_engine {

    use iota::table::{Self, Table};
    use move_cmtat::icmtat;
    use move_cmtat::allowlist;

    /// Errors
    const ETransferRestricted: u64 = 600;

    /// Rule engine state (kept for backwards compatibility)
    public struct RuleEngine has key, store {
        id: object::UID,
        custom_rules: Table<vector<u8>, bool>,
    }

    /// Initialize rule engine
    public fun init_rule_engine(ctx: &mut tx_context::TxContext): RuleEngine {
        RuleEngine {
            id: object::new(ctx),
            custom_rules: table::new(ctx),
        }
    }

    /// Get restriction code getters
    public fun restriction_code_valid(): u8 { icmtat::restriction_code_valid() }
    public fun restriction_code_not_allowlisted(): u8 { icmtat::restriction_code_not_allowlisted() }

    /// Validate transfer with allowlist check only
    /// Freeze/pause validation now handled by native DenyList
    public fun validate_transfer_with_allowlist(
        allowlist_state: &allowlist::AllowlistState,
        to: address
    ): u8 {
        // Check if receiver is allowlisted
        if (!allowlist::is_allowlisted(allowlist_state, to)) {
            return restriction_code_not_allowlisted()
        };

        restriction_code_valid()
    }

    /// Require that a transfer is valid (restriction code is 0)
    /// Aborts if the transfer is restricted
    public fun require_valid_transfer(restriction_code: u8) {
        assert!(restriction_code == restriction_code_valid(), ETransferRestricted);
    }
}
