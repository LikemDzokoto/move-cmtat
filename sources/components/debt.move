/// Debt Component - Debt Securities Management
/// Specialized functionality for corporate bonds and debt instruments
module move_cmtat::debt {
    use std::string::String;


    /// Errors
    const EDefaultFlagged: u64 = 401;

    /// Debt information state
    public struct DebtState has key, store {
        id: UID,
        debt_info: String,
        credit_events: String,
        debt_engine: address,  // External contract for debt calculations
        default_flagged: bool,
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

    /// Get debt information
    public fun get_debt(state: &DebtState): String {
        state.debt_info
    }

    /// Set debt information
    public fun set_debt(state: &mut DebtState, debt_info: String) {
        state.debt_info = debt_info;
    }

    /// Get credit events
    public fun get_credit_events(state: &DebtState): String {
        state.credit_events
    }

    /// Set credit events
    public fun set_credit_events(state: &mut DebtState, events: String) {
        state.credit_events = events;
    }

    /// Get debt engine address
    public fun get_debt_engine(state: &DebtState): address {
        state.debt_engine
    }

    /// Set debt engine
    public fun set_debt_engine(state: &mut DebtState, engine: address) {
        state.debt_engine = engine;
    }

    /// Check if default is flagged
    public fun is_default_flagged(state: &DebtState): bool {
        state.default_flagged
    }

    /// Flag default event
    public fun flag_default(state: &mut DebtState) {
        state.default_flagged = true;
    }

    /// Require not in default
    public fun require_not_in_default(state: &DebtState) {
        assert!(!state.default_flagged, EDefaultFlagged);
    }
}
