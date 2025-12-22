/// CMTAT Interface Definitions
/// Defines the core interfaces for CMTAT token implementations
module move_cmtat::icmtat {
    use std::string::String;

    /// Restriction codes for transfer validation (ERC-1404 compatible)
    const RESTRICTION_CODE_VALID: u8 = 0;
    const RESTRICTION_CODE_PAUSED: u8 = 1;
    const RESTRICTION_CODE_FROZEN_SENDER: u8 = 2;
    const RESTRICTION_CODE_FROZEN_RECEIVER: u8 = 3;
    const RESTRICTION_CODE_NOT_ALLOWLISTED: u8 = 4;
    const RESTRICTION_CODE_INSUFFICIENT_BALANCE: u8 = 5;

    /// Role constants (matching Cairo implementation)
    const DEFAULT_ADMIN_ROLE: vector<u8> = b"DEFAULT_ADMIN_ROLE";
    const MINTER_ROLE: vector<u8> = b"MINTER_ROLE";
    const BURNER_ROLE: vector<u8> = b"BURNER_ROLE";
    const PAUSER_ROLE: vector<u8> = b"PAUSER_ROLE";
    const ENFORCER_ROLE: vector<u8> = b"ENFORCER_ROLE";
    const ERC20ENFORCER_ROLE: vector<u8> = b"ERC20ENFORCER_ROLE";
    const SNAPSHOOTER_ROLE: vector<u8> = b"SNAPSHOOTER_ROLE";
    const DOCUMENT_ROLE: vector<u8> = b"DOCUMENT_ROLE";
    const EXTRA_INFORMATION_ROLE: vector<u8> = b"EXTRA_INFORMATION_ROLE";
    const DEBT_ROLE: vector<u8> = b"DEBT_ROLE";

    /// Base CMTAT interface - common to all modules
    public fun restriction_code_valid(): u8 { RESTRICTION_CODE_VALID }
    public fun restriction_code_paused(): u8 { RESTRICTION_CODE_PAUSED }
    public fun restriction_code_frozen_sender(): u8 { RESTRICTION_CODE_FROZEN_SENDER }
    public fun restriction_code_frozen_receiver(): u8 { RESTRICTION_CODE_FROZEN_RECEIVER }
    public fun restriction_code_not_allowlisted(): u8 { RESTRICTION_CODE_NOT_ALLOWLISTED }
    public fun restriction_code_insufficient_balance(): u8 { RESTRICTION_CODE_INSUFFICIENT_BALANCE }

    /// Role getters
    public fun default_admin_role(): vector<u8> { DEFAULT_ADMIN_ROLE }
    public fun minter_role(): vector<u8> { MINTER_ROLE }
    public fun burner_role(): vector<u8> { BURNER_ROLE }
    public fun pauser_role(): vector<u8> { PAUSER_ROLE }
    public fun enforcer_role(): vector<u8> { ENFORCER_ROLE }
    public fun erc20enforcer_role(): vector<u8> { ERC20ENFORCER_ROLE }
    public fun snapshooter_role(): vector<u8> { SNAPSHOOTER_ROLE }
    public fun document_role(): vector<u8> { DOCUMENT_ROLE }
    public fun extra_information_role(): vector<u8> { EXTRA_INFORMATION_ROLE }
    public fun debt_role(): vector<u8> { DEBT_ROLE }
}
