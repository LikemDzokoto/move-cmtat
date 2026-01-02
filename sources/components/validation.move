/// Validation Component - Transfer Validation (ERC-1404)
/// Implements transfer restriction logic with detailed error codes
module move_cmtat::validation {
    use std::string::String;
    use move_cmtat::icmtat;

    /// Restriction messages
    const MSG_VALID: vector<u8> = b"Transfer allowed";
    const MSG_PAUSED: vector<u8> = b"Contract is paused";
    const MSG_FROZEN_SENDER: vector<u8> = b"Sender address is frozen";
    const MSG_FROZEN_RECEIVER: vector<u8> = b"Receiver address is frozen";
    const MSG_NOT_ALLOWLISTED: vector<u8> = b"Address not in allowlist";
    const MSG_INSUFFICIENT_BALANCE: vector<u8> = b"Insufficient active balance";

    /// Get message for restriction code
    public fun get_restriction_message(code: u8): String {
        if (code == icmtat::restriction_code_valid()) {
            string::utf8(MSG_VALID)
        } else if (code == icmtat::restriction_code_paused()) {
            string::utf8(MSG_PAUSED)
        } else if (code == icmtat::restriction_code_frozen_sender()) {
            string::utf8(MSG_FROZEN_SENDER)
        } else if (code == icmtat::restriction_code_frozen_receiver()) {
            string::utf8(MSG_FROZEN_RECEIVER)
        } else if (code == icmtat::restriction_code_not_allowlisted()) {
            string::utf8(MSG_NOT_ALLOWLISTED)
        } else if (code == icmtat::restriction_code_insufficient_balance()) {
            string::utf8(MSG_INSUFFICIENT_BALANCE)
        } else {
            string::utf8(b"Unknown restriction")
        }
    }
}
