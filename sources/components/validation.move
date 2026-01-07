/// Validation Component - Transfer Validation
module move_cmtat::validation {
    use std::string::{Self, String};  

    // Restriction codes
    const RESTRICTION_CODE_VALID: u8 = 0;
    const RESTRICTION_CODE_PAUSED: u8 = 1;
    const RESTRICTION_CODE_FROZEN_SENDER: u8 = 2;
    const RESTRICTION_CODE_FROZEN_RECEIVER: u8 = 3;
    const RESTRICTION_CODE_NOT_ALLOWLISTED: u8 = 4;
    const RESTRICTION_CODE_INSUFFICIENT_BALANCE: u8 = 5;

    // Message constants
    const MSG_VALID: vector<u8> = b"Transfer allowed";
    const MSG_PAUSED: vector<u8> = b"Contract is paused";
    const MSG_FROZEN_SENDER: vector<u8> = b"Sender address is frozen";
    const MSG_FROZEN_RECEIVER: vector<u8> = b"Receiver address is frozen";
    const MSG_NOT_ALLOWLISTED: vector<u8> = b"Address not in allowlist";
    const MSG_INSUFFICIENT_BALANCE: vector<u8> = b"Insufficient active balance";

    public fun message_for_restriction_code(code: u8): String {
        if (code == RESTRICTION_CODE_VALID) {
            string::utf8(MSG_VALID)
        } else if (code == RESTRICTION_CODE_PAUSED) {
            string::utf8(MSG_PAUSED)
        } else if (code == RESTRICTION_CODE_FROZEN_SENDER) {
            string::utf8(MSG_FROZEN_SENDER)
        } else if (code == RESTRICTION_CODE_FROZEN_RECEIVER) {
            string::utf8(MSG_FROZEN_RECEIVER)
        } else if (code == RESTRICTION_CODE_NOT_ALLOWLISTED) {
            string::utf8(MSG_NOT_ALLOWLISTED)
        } else if (code == RESTRICTION_CODE_INSUFFICIENT_BALANCE) {
            string::utf8(MSG_INSUFFICIENT_BALANCE)
        } else {
            string::utf8(b"Unknown restriction")
        }
    }

    /// Alias for message_for_restriction_code (used by some contracts)
    public fun get_restriction_message(code: u8): String {
        message_for_restriction_code(code)
    }

    // Getter functions
    public fun restriction_code_valid(): u8 { RESTRICTION_CODE_VALID }
    public fun restriction_code_paused(): u8 { RESTRICTION_CODE_PAUSED }
    public fun restriction_code_frozen_sender(): u8 { RESTRICTION_CODE_FROZEN_SENDER }
    public fun restriction_code_frozen_receiver(): u8 { RESTRICTION_CODE_FROZEN_RECEIVER }
    public fun restriction_code_not_allowlisted(): u8 { RESTRICTION_CODE_NOT_ALLOWLISTED }
    public fun restriction_code_insufficient_balance(): u8 { RESTRICTION_CODE_INSUFFICIENT_BALANCE }
}
