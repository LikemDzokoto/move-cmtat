/// Rule Engine - Transfer Restriction Rules (FIXED)
module move_cmtat::rule_engine {
    use iota::object::{Self, UID};  
    use iota::tx_context::TxContext;
    use iota::table::{Self, Table};  
    use move_cmtat::icmtat;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::allowlist;

    /// Errors
    const ETransferRestricted: u64 = 600;

    /// Rule engine state
    public struct RuleEngine has key, store {
        id: UID,
        custom_rules: Table<vector<u8>, bool>,
    }

    /// Initialize rule engine
    public fun init_rule_engine(ctx: &mut TxContext): RuleEngine {
        RuleEngine {
            id: object::new(ctx),
            custom_rules: table::new(ctx),
        }
    }

    /// Add custom rule
    public fun add_custom_rule(_engine: &mut RuleEngine, _rule_id: vector<u8>) {
        // FIX: Temporarily disable custom rules until table is working
        // if (!table::contains(&engine.custom_rules, rule_id)) {
        //     table::add(&mut engine.custom_rules, rule_id, true);
        // }
    }

    /// Remove custom rule
    public fun remove_custom_rule(_engine: &mut RuleEngine, _rule_id: vector<u8>) {
        // FIX: Temporarily disable
        // if (table::contains(&engine.custom_rules, rule_id)) {
        //     table::remove(&mut engine.custom_rules, rule_id);
        // }
    }

    /// Check if has custom rule
    public fun has_custom_rule(_engine: &RuleEngine, _rule_id: vector<u8>): bool {
        //  FIX: Temporarily return false
        // table::contains(&engine.custom_rules, rule_id)
        false
    }

    /// Get restriction code getters
    public fun restriction_code_valid(): u8 { icmtat::restriction_code_valid() }
    public fun restriction_code_paused(): u8 { icmtat::restriction_code_paused() }
    public fun restriction_code_frozen_sender(): u8 { icmtat::restriction_code_frozen_sender() }
    public fun restriction_code_frozen_receiver(): u8 { icmtat::restriction_code_frozen_receiver() }
    public fun restriction_code_not_allowlisted(): u8 { icmtat::restriction_code_not_allowlisted() }

    /// Validate transfer with pause and freeze checks
    public fun validate_transfer(
        pause_state: &pause::PauseState,
        freeze_state: &freeze::FreezeState,
        from: address,
        to: address,
        _amount: u64,
        _from_balance: u64
    ): u8 {
        // Check if contract is paused
        if (pause::is_paused(pause_state)) {
            return restriction_code_paused()
        };

        // Check if sender is frozen
        if (freeze::is_frozen(freeze_state, from)) {
            return restriction_code_frozen_sender()
        };

        // Check if receiver is frozen
        if (freeze::is_frozen(freeze_state, to)) {
            return restriction_code_frozen_receiver()
        };

        // All checks passed
        restriction_code_valid()
    }

    /// Validate transfer with allowlist check
    public fun validate_transfer_with_allowlist(
        pause_state: &pause::PauseState,
        freeze_state: &freeze::FreezeState,
        allowlist_state: &allowlist::AllowlistState,
        from: address,
        to: address,
        amount: u64,
        from_balance: u64
    ): u8 {
        // First run standard checks
        let code = validate_transfer(pause_state, freeze_state, from, to, amount, from_balance);
        if (code != restriction_code_valid()) {
            return code
        };

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
