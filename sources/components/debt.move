/// Debt Component - Debt Securities Management
/// Provides debt-specific state management for bond tokens
/// Tracks debt information, credit events, and default status
module move_cmtat::debt {
    use std::string::String;

    /// Errors
    const EDebtInDefault: u64 = 400;

    /// Debt state for tracking bond/debt security information
    public struct DebtState has key, store {
        id: UID,
        debt_info: String,        // Bond terms, coupon rate, maturity date
        credit_events: String,    // Historical credit events
        debt_engine: address,     // External debt calculation contract
        default_flagged: bool,    // Default status blocks operations
    }

    /// Initialize debt state
    public fun init_debt_state(ctx: &mut TxContext): DebtState {
        DebtState {
            id: object::new(ctx),
            debt_info: std::string::utf8(b""),
            credit_events: std::string::utf8(b""),
            debt_engine: @0x0,
            default_flagged: false,
        }
    }

    // ========== GETTERS ==========

    /// Get debt information
    public fun get_debt(state: &DebtState): String {
        state.debt_info
    }

    /// Get credit events
    public fun get_credit_events(state: &DebtState): String {
        state.credit_events
    }

    /// Get debt engine address
    public fun get_debt_engine(state: &DebtState): address {
        state.debt_engine
    }

    /// Check if debt is in default
    public fun is_default_flagged(state: &DebtState): bool {
        state.default_flagged
    }

    // ========== SETTERS ==========

    /// Set debt information (bond terms)
    public fun set_debt(state: &mut DebtState, debt_info: String) {
        state.debt_info = debt_info;
    }

    /// Set credit events history
    public fun set_credit_events(state: &mut DebtState, events: String) {
        state.credit_events = events;
    }

    /// Set debt engine address
    public fun set_debt_engine(state: &mut DebtState, engine: address) {
        state.debt_engine = engine;
    }

    /// Flag debt as in default
    public fun flag_default(state: &mut DebtState) {
        state.default_flagged = true;
    }

    /// Clear default flag (debt cured)
    public fun clear_default(state: &mut DebtState) {
        state.default_flagged = false;
    }

    // ========== VALIDATION ==========

    /// Require debt is not in default
    /// Used by minting/transfer functions to block operations during default
    public fun require_not_in_default(state: &DebtState) {
        assert!(!state.default_flagged, EDebtInDefault);
    }
}
