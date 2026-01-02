/// Rule Engine - Transfer Restriction Rules
/// Implements transfer validation logic for ERC-1404 compliance
module move_cmtat::rule_engine {
    use iota::table::Table;
    use move_cmtat::icmtat;
    use move_cmtat::pause::PauseState;
    use move_cmtat::freeze::FreezeState;
    use move_cmtat::allowlist::AllowlistState;

    /// Errors
    const ETransferRestricted: u64 = 600;

    /// Rule engine state
    public struct RuleEngine has key, store {
        id: UID,
        custom_rules: Table<vector<u8>, bool>,  // Custom rule identifiers
    }

    /// Initialize rule engine
    public fun init_rule_engine(ctx: &mut TxContext): RuleEngine {
        RuleEngine {
            id: object::new(ctx),
            custom_rules: table::new(ctx),
        }
    }

    /// Validate transfer with all rules
    /// Returns restriction code (0 = valid, >0 = restricted)
    /// Note: from_balance is now the value of the Coin<CMTAT> being transferred
    public fun validate_transfer(
        pause_state: &PauseState,
        freeze_state: &FreezeState,
        from: address,
        to: address,
        amount: u64,
        from_balance: u64,
    ): u8 {
        // Check if paused
        if (move_cmtat::pause::is_paused(pause_state)) {
            return icmtat::restriction_code_paused()
        };

        // Check if deactivated
        if (move_cmtat::pause::is_deactivated(pause_state)) {
            return icmtat::restriction_code_paused()
        };

        // Check if sender is frozen
        if (move_cmtat::freeze::is_frozen(freeze_state, from)) {
            return icmtat::restriction_code_frozen_sender()
        };

        // Check if receiver is frozen
        if (move_cmtat::freeze::is_frozen(freeze_state, to)) {
            return icmtat::restriction_code_frozen_receiver()
        };

        // Check active balance (considering frozen tokens)
        let active_balance = move_cmtat::freeze::get_active_balance(from_balance, freeze_state, from);
        if (active_balance < amount) {
            return icmtat::restriction_code_insufficient_balance()
        };

        // All checks passed
        icmtat::restriction_code_valid()
    }

    /// Validate transfer with allowlist
    /// Note: from_balance is now the value of the Coin<CMTAT> being transferred
    public fun validate_transfer_with_allowlist(
        pause_state: &PauseState,
        freeze_state: &FreezeState,
        allowlist_state: &AllowlistState,
        from: address,
        to: address,
        amount: u64,
        from_balance: u64,
    ): u8 {
        // First run standard validation
        let code = validate_transfer(pause_state, freeze_state, from, to, amount, from_balance);
        if (code != icmtat::restriction_code_valid()) {
            return code
        };

        // Check allowlist if enabled
        if (move_cmtat::allowlist::is_enabled(allowlist_state)) {
            if (!move_cmtat::allowlist::is_allowlisted(allowlist_state, from)) {
                return icmtat::restriction_code_not_allowlisted()
            };
            if (!move_cmtat::allowlist::is_allowlisted(allowlist_state, to)) {
                return icmtat::restriction_code_not_allowlisted()
            };
        };

        icmtat::restriction_code_valid()
    }

    /// Add custom rule
    public fun add_custom_rule(engine: &mut RuleEngine, rule_id: vector<u8>) {
        if (!table::contains(&engine.custom_rules, rule_id)) {
            table::add(&mut engine.custom_rules, rule_id, true);
        }
    }

    /// Remove custom rule
    public fun remove_custom_rule(engine: &mut RuleEngine, rule_id: vector<u8>) {
        if (table::contains(&engine.custom_rules, rule_id)) {
            table::remove(&mut engine.custom_rules, rule_id);
        }
    }

    /// Check if custom rule exists
    public fun has_custom_rule(engine: &RuleEngine, rule_id: vector<u8>): bool {
        table::contains(&engine.custom_rules, rule_id)
    }

    /// Require transfer to be valid
    public fun require_valid_transfer(restriction_code: u8) {
        assert!(restriction_code == icmtat::restriction_code_valid(), ETransferRestricted);
    }
}
