/// Pause Component - Pause/Unpause/Deactivate Functionality
/// Provides circuit breaker mechanism for emergency stops
module move_cmtat::pause {
 
    /// Errors
    const EPaused: u64 = 100;
    const ENotPaused: u64 = 101;
    const EDeactivated: u64 = 102;

    /// Pause state
    public struct PauseState has key, store {
        id: UID,
        paused: bool,
        deactivated: bool,
    }

    /// Initialize pause state
    public fun init_pause_state(ctx: &mut TxContext): PauseState {
        PauseState {
            id: object::new(ctx),
            paused: false,
            deactivated: false,
        }
    }

    /// Check if paused
    public fun is_paused(state: &PauseState): bool {
        state.paused
    }

    /// Check if deactivated
    public fun is_deactivated(state: &PauseState): bool {
        state.deactivated
    }

    /// Pause the contract
    public fun pause(state: &mut PauseState) {
        assert!(!state.deactivated, EDeactivated);
        assert!(!state.paused, EPaused);
        state.paused = true;
    }

    /// Unpause the contract
    public fun unpause(state: &mut PauseState) {
        assert!(!state.deactivated, EDeactivated);
        assert!(state.paused, ENotPaused);
        state.paused = false;
    }

    /// Deactivate the contract (permanent pause)
    public fun deactivate(state: &mut PauseState) {
        state.deactivated = true;
        state.paused = true;
    }

    /// Require not paused
    public fun require_not_paused(state: &PauseState) {
        assert!(!state.paused, EPaused);
        assert!(!state.deactivated, EDeactivated);
    }
}
