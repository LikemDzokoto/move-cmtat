/// RuleEngine V2 - Enhanced with Conditional Transfer Support
/// Integrates ERC-1404 compliance, Swiss law (Vinkulierung) compliance,
/// and comprehensive transfer restriction codes
module move_cmtat::rule_engine_v2 {

    use iota::table::{Self, Table};
    use iota::clock::Clock;
    use iota::event;
    use std::string::{Self, String};
    use std::option::Option;
    use std::vector;
    use move_cmtat::allowlist;

    // ============ STATUS CONSTANTS ============
    const STATUS_NONE: u8 = 0;
    const STATUS_WAITING: u8 = 1;
    const STATUS_APPROVED: u8 = 2;
    const STATUS_DENIED: u8 = 3;
    const STATUS_EXECUTED: u8 = 4;
    const STATUS_EXPIRED: u8 = 5;

    // ============ RESTRICTION CODES ============
    const CODE_VALID: u8 = 0;
    const CODE_PAUSED: u8 = 1;
    const CODE_FROZEN_SENDER: u8 = 2;
    const CODE_FROZEN_RECEIVER: u8 = 3;
    const CODE_NOT_ALLOWLISTED: u8 = 4;
    const CODE_INSUFFICIENT_BALANCE: u8 = 5;

    // Conditional transfer codes
    const CODE_CONDITIONAL_REQUIRED: u8 = 10;
    const CODE_PENDING_APPROVAL: u8 = 11;
    const CODE_REQUEST_DENIED: u8 = 12;
    const CODE_REQUEST_EXPIRED: u8 = 13;
    const CODE_ALREADY_EXECUTED: u8 = 14;
    const CODE_INVALID_REQUEST: u8 = 15;
    const CODE_MINT_NOT_AUTHORIZED: u8 = 16;
    const CODE_BURN_NOT_AUTHORIZED: u8 = 17;

    // ============ ERROR CODES ============
    const ERequestAlreadyExists: u64 = 600;
    const ERequestNotFound: u64 = 601;
    const ENotWaiting: u64 = 602;
    const ENotApproved: u64 = 603;
    const ERequestExpired: u64 = 604;
    const ENotOperator: u64 = 605;
    const ETransferRestricted: u64 = 609;

    // ============ DEFAULT TIME LIMITS ============
    const DEFAULT_APPROVAL_DEADLINE_MS: u64 = 90 * 24 * 60 * 60 * 1000;
    const DEFAULT_EXECUTION_DEADLINE_MS: u64 = 30 * 24 * 60 * 60 * 1000;

    // ============ DATA STRUCTURES ============

    public struct TransferConfig has store, drop, copy {
        auto_transfer_enabled: bool,
        auto_approval_enabled: bool,
        approval_deadline_ms: u64,
        execution_deadline_ms: u64,
        authorized_mint_address: Option<address>,
        authorized_burn_address: Option<address>,
    }

    public struct TransferRequest has store, drop, copy {
        id: u64,
        from: address,
        to: address,
        value: u64,
        status: u8,
        created_at: u64,
        approval_deadline: u64,
        execution_deadline: u64,
        operator_approval_time: Option<u64>,
        denial_reason: Option<String>,
    }

    public struct RuleEngine has key, store {
        id: object::UID,
        custom_rules: Table<vector<u8>, bool>,
        transfer_requests: Table<vector<u8>, TransferRequest>,
        request_counter: u64,
        config: TransferConfig,
        conditional_whitelist: Table<address, bool>,
        operator: address,
    }

    // ============ EVENTS ============

    public struct RequestCreated has copy, drop {
        request_id: u64,
        from: address,
        to: address,
        value: u64,
        created_at: u64,
        approval_deadline: u64,
    }

    public struct RequestApproved has copy, drop {
        request_id: u64,
        from: address,
        to: address,
        value: u64,
        operator: address,
        approved_at: u64,
        execution_deadline: u64,
    }

    public struct RequestDenied has copy, drop {
        request_id: u64,
        from: address,
        to: address,
        value: u64,
        operator: address,
        reason: String,
    }

    public struct RequestExecuted has copy, drop {
        request_id: u64,
        from: address,
        to: address,
        value: u64,
        executed_by: address,
        executed_at: u64,
    }

    public struct WhitelistAdded has copy, drop {
        operator: address,
        account: address,
    }

    public struct WhitelistRemoved has copy, drop {
        operator: address,
        account: address,
    }

    // ============ INITIALIZATION ============

    public fun init_rule_engine_v2(
        ctx: &mut tx_context::TxContext
    ): RuleEngine {
        RuleEngine {
            id: object::new(ctx),
            custom_rules: table::new(ctx),
            transfer_requests: table::new(ctx),
            request_counter: 0,
            config: TransferConfig {
                auto_transfer_enabled: false,
                auto_approval_enabled: true,
                approval_deadline_ms: DEFAULT_APPROVAL_DEADLINE_MS,
                execution_deadline_ms: DEFAULT_EXECUTION_DEADLINE_MS,
                authorized_mint_address: option::none(),
                authorized_burn_address: option::none(),
            },
            conditional_whitelist: table::new(ctx),
            operator: tx_context::sender(ctx),
        }
    }

    // ============ RESTRICTION CODE GETTERS ============

    public fun restriction_code_valid(): u8 { CODE_VALID }
    public fun restriction_code_paused(): u8 { CODE_PAUSED }
    public fun restriction_code_frozen_sender(): u8 { CODE_FROZEN_SENDER }
    public fun restriction_code_frozen_receiver(): u8 { CODE_FROZEN_RECEIVER }
    public fun restriction_code_not_allowlisted(): u8 { CODE_NOT_ALLOWLISTED }
    public fun restriction_code_insufficient_balance(): u8 { CODE_INSUFFICIENT_BALANCE }
    public fun restriction_code_conditional_required(): u8 { CODE_CONDITIONAL_REQUIRED }
    public fun restriction_code_pending_approval(): u8 { CODE_PENDING_APPROVAL }
    public fun restriction_code_request_denied(): u8 { CODE_REQUEST_DENIED }
    public fun restriction_code_request_expired(): u8 { CODE_REQUEST_EXPIRED }
    public fun restriction_code_already_executed(): u8 { CODE_ALREADY_EXECUTED }
    public fun restriction_code_invalid_request(): u8 { CODE_INVALID_REQUEST }
    public fun restriction_code_mint_not_authorized(): u8 { CODE_MINT_NOT_AUTHORIZED }
    public fun restriction_code_burn_not_authorized(): u8 { CODE_BURN_NOT_AUTHORIZED }

    // ============ MESSAGE FOR RESTRICTION CODE ============

    public fun message_for_restriction_code(code: u8): String {
        if (code == CODE_VALID) {
            string::utf8(b"Transfer allowed")
        } else if (code == CODE_PAUSED) {
            string::utf8(b"Contract is paused")
        } else if (code == CODE_FROZEN_SENDER) {
            string::utf8(b"Sender address is frozen")
        } else if (code == CODE_FROZEN_RECEIVER) {
            string::utf8(b"Receiver address is frozen")
        } else if (code == CODE_NOT_ALLOWLISTED) {
            string::utf8(b"Address not in allowlist")
        } else if (code == CODE_INSUFFICIENT_BALANCE) {
            string::utf8(b"Insufficient active balance")
        } else if (code == CODE_CONDITIONAL_REQUIRED) {
            string::utf8(b"Transfer requires conditional approval")
        } else if (code == CODE_PENDING_APPROVAL) {
            string::utf8(b"Transfer request pending approval")
        } else if (code == CODE_REQUEST_DENIED) {
            string::utf8(b"Transfer request was denied")
        } else if (code == CODE_REQUEST_EXPIRED) {
            string::utf8(b"Transfer request has expired")
        } else if (code == CODE_ALREADY_EXECUTED) {
            string::utf8(b"Transfer request already executed")
        } else if (code == CODE_INVALID_REQUEST) {
            string::utf8(b"Invalid transfer request")
        } else if (code == CODE_MINT_NOT_AUTHORIZED) {
            string::utf8(b"Mint requires conditional approval")
        } else if (code == CODE_BURN_NOT_AUTHORIZED) {
            string::utf8(b"Burn requires conditional approval")
        } else {
            string::utf8(b"Unknown restriction")
        }
    }

    // ============ KEY GENERATION ============

    fun generate_request_key(from: address, to: address, value: u64): vector<u8> {
        let mut key = from.to_bytes();
        key.append(to.to_bytes());
        let value_bytes = encode_u64(value);
        key.append(value_bytes);
        key
    }

    fun encode_u64(value: u64): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut temp = value;
        let mut i = 0;
        while (i < 8) {
            vector::push_back(&mut bytes, (temp as u8));
            temp = temp >> 8;
            i = i + 1;
        };
        bytes
    }

    // ============ WHITELIST MANAGEMENT ============

    public fun is_conditional_whitelisted(
        rule_engine: &RuleEngine,
        account: address
    ): bool {
        table::contains(&rule_engine.conditional_whitelist, account)
    }

    // ============ TRANSFER REQUEST LIFECYCLE ============

    public entry fun create_transfer_request(
        rule_engine: &mut RuleEngine,
        to: address,
        value: u64,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        let from = tx_context::sender(ctx);
        let key = generate_request_key(from, to, value);

        assert!(!table::contains(&rule_engine.transfer_requests, key), ERequestAlreadyExists);

        let now = clock.timestamp_ms();
        let request = TransferRequest {
            id: rule_engine.request_counter,
            from,
            to,
            value,
            status: STATUS_WAITING,
            created_at: now,
            approval_deadline: now + rule_engine.config.approval_deadline_ms,
            execution_deadline: 0,
            operator_approval_time: option::none(),
            denial_reason: option::none(),
        };

        table::add(&mut rule_engine.transfer_requests, key, request);
        rule_engine.request_counter = rule_engine.request_counter + 1;

        event::emit(RequestCreated {
            request_id: request.id,
            from,
            to,
            value,
            created_at: now,
            approval_deadline: request.approval_deadline,
        });
    }

    public entry fun approve_request(
        rule_engine: &mut RuleEngine,
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        let key = generate_request_key(from, to, value);
        let request = table::borrow_mut(&mut rule_engine.transfer_requests, key);

        assert!(request.status == STATUS_WAITING, ENotWaiting);

        let now = clock.timestamp_ms();
        assert!(now <= request.approval_deadline, ERequestExpired);

        request.status = STATUS_APPROVED;
        request.operator_approval_time = option::some(now);
        request.execution_deadline = now + rule_engine.config.execution_deadline_ms;

        event::emit(RequestApproved {
            request_id: request.id,
            from,
            to,
            value,
            operator,
            approved_at: now,
            execution_deadline: request.execution_deadline,
        });
    }

    public entry fun deny_request(
        rule_engine: &mut RuleEngine,
        from: address,
        to: address,
        value: u64,
        reason: String,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        let key = generate_request_key(from, to, value);
        let request = table::borrow_mut(&mut rule_engine.transfer_requests, key);

        assert!(request.status == STATUS_WAITING, ENotWaiting);

        request.status = STATUS_DENIED;
        request.denial_reason = option::some(reason);

        event::emit(RequestDenied {
            request_id: request.id,
            from,
            to,
            value,
            operator,
            reason,
        });
    }

    public fun mark_executed(
        rule_engine: &mut RuleEngine,
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        ctx: &tx_context::TxContext
    ) {
        let key = generate_request_key(from, to, value);
        let request = table::borrow_mut(&mut rule_engine.transfer_requests, key);

        assert!(request.status == STATUS_APPROVED, ENotApproved);

        let now = clock.timestamp_ms();
        assert!(now <= request.execution_deadline, ERequestExpired);

        request.status = STATUS_EXECUTED;

        event::emit(RequestExecuted {
            request_id: request.id,
            from,
            to,
            value,
            executed_by: tx_context::sender(ctx),
            executed_at: now,
        });
    }

    // ============ VALIDATION FUNCTIONS ============

    public fun validate_transfer(
        rule_engine: &RuleEngine,
        allowlist_state: &allowlist::AllowlistState,
        from: address,
        to: address,
        value: u64,
        clock: &Clock
    ): u8 {
        if (is_conditional_whitelisted(rule_engine, from) && 
            is_conditional_whitelisted(rule_engine, to)) {
            return CODE_VALID
        };

        let key = generate_request_key(from, to, value);

        if (!table::contains(&rule_engine.transfer_requests, key)) {
            if (!allowlist::is_allowlisted(allowlist_state, to)) {
                return CODE_NOT_ALLOWLISTED
            };
            return CODE_VALID
        };

        let request = table::borrow(&rule_engine.transfer_requests, key);
        let now = clock.timestamp_ms();

        if (rule_engine.config.auto_approval_enabled && 
            request.status == STATUS_WAITING && 
            now > request.approval_deadline) {
            return CODE_VALID
        };

        match (request.status) {
            STATUS_WAITING => CODE_PENDING_APPROVAL,
            STATUS_APPROVED => {
                if (now > request.execution_deadline) {
                    CODE_REQUEST_EXPIRED
                } else {
                    CODE_VALID
                }
            },
            STATUS_DENIED => CODE_REQUEST_DENIED,
            STATUS_EXECUTED => CODE_ALREADY_EXECUTED,
            STATUS_EXPIRED => CODE_REQUEST_EXPIRED,
            _ => CODE_INVALID_REQUEST,
        }
    }

    public fun validate_mint(
        rule_engine: &RuleEngine,
        to: address,
        _value: u64,
        _clock: &Clock
    ): u8 {
        if (option::is_some(&rule_engine.config.authorized_mint_address)) {
            let authorized = option::borrow(&rule_engine.config.authorized_mint_address);
            if (*authorized == to) {
                return CODE_VALID
            };
        };
        CODE_MINT_NOT_AUTHORIZED
    }

    public fun validate_burn(
        rule_engine: &RuleEngine,
        from: address,
        _value: u64,
        _clock: &Clock
    ): u8 {
        if (option::is_some(&rule_engine.config.authorized_burn_address)) {
            let authorized = option::borrow(&rule_engine.config.authorized_burn_address);
            if (*authorized == from) {
                return CODE_VALID
            };
        };
        CODE_BURN_NOT_AUTHORIZED
    }

    public fun detect_transfer_restriction(
        rule_engine: &RuleEngine,
        allowlist_state: &allowlist::AllowlistState,
        from: address,
        to: address,
        value: u64,
        clock: &Clock
    ): u8 {
        validate_transfer(rule_engine, allowlist_state, from, to, value, clock)
    }

    public fun require_valid_transfer(
        rule_engine: &RuleEngine,
        allowlist_state: &allowlist::AllowlistState,
        from: address,
        to: address,
        value: u64,
        clock: &Clock
    ) {
        let code = validate_transfer(rule_engine, allowlist_state, from, to, value, clock);
        assert!(code == CODE_VALID, ETransferRestricted)
    }

    // ============ WHITELIST MANAGEMENT ============

    public entry fun add_conditional_whitelist(
        rule_engine: &mut RuleEngine,
        account: address,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (!table::contains(&rule_engine.conditional_whitelist, account)) {
            table::add(&mut rule_engine.conditional_whitelist, account, true);
        };

        event::emit(WhitelistAdded { operator, account });
    }

    public entry fun remove_conditional_whitelist(
        rule_engine: &mut RuleEngine,
        account: address,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (table::contains(&rule_engine.conditional_whitelist, account)) {
            table::remove(&mut rule_engine.conditional_whitelist, account);
        };

        event::emit(WhitelistRemoved { operator, account });
    }

    // ============ QUERY FUNCTIONS ============

    public fun get_request_status(
        rule_engine: &RuleEngine,
        from: address,
        to: address,
        value: u64
    ): u8 {
        let key = generate_request_key(from, to, value);
        if (!table::contains(&rule_engine.transfer_requests, key)) {
            return STATUS_NONE
        };
        table::borrow(&rule_engine.transfer_requests, key).status
    }

    public fun can_execute(
        rule_engine: &RuleEngine,
        allowlist_state: &allowlist::AllowlistState,
        from: address,
        to: address,
        value: u64,
        clock: &Clock
    ): bool {
        let code = validate_transfer(rule_engine, allowlist_state, from, to, value, clock);
        code == CODE_VALID
    }

    public fun get_request(
        rule_engine: &RuleEngine,
        from: address,
        to: address,
        value: u64
    ): (u64, u8, u64, u64) {
        let key = generate_request_key(from, to, value);
        assert!(table::contains(&rule_engine.transfer_requests, key), ERequestNotFound);
        let request = table::borrow(&rule_engine.transfer_requests, key);
        (request.id, request.status, request.approval_deadline, request.execution_deadline)
    }

    public fun get_request_counter(rule_engine: &RuleEngine): u64 {
        rule_engine.request_counter
    }

    // ============ CONFIGURATION FUNCTIONS ============

    public entry fun set_auto_transfer(
        rule_engine: &mut RuleEngine,
        enabled: bool,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.config.auto_transfer_enabled = enabled;
    }

    public entry fun set_auto_approval(
        rule_engine: &mut RuleEngine,
        enabled: bool,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.config.auto_approval_enabled = enabled;
    }

    public entry fun set_time_limits(
        rule_engine: &mut RuleEngine,
        approval_deadline_ms: u64,
        execution_deadline_ms: u64,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.config.approval_deadline_ms = approval_deadline_ms;
        rule_engine.config.execution_deadline_ms = execution_deadline_ms;
    }

    public entry fun set_authorized_mint_address(
        rule_engine: &mut RuleEngine,
        address: Option<address>,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.config.authorized_mint_address = address;
    }

    public entry fun set_authorized_burn_address(
        rule_engine: &mut RuleEngine,
        address: Option<address>,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.config.authorized_burn_address = address;
    }

    public entry fun transfer_operator_role(
        rule_engine: &mut RuleEngine,
        new_operator: address,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);
        rule_engine.operator = new_operator;
    }

    // ============ STATUS CONSTANT GETTERS ============

    public fun status_none(): u8 { STATUS_NONE }
    public fun status_waiting(): u8 { STATUS_WAITING }
    public fun status_approved(): u8 { STATUS_APPROVED }
    public fun status_denied(): u8 { STATUS_DENIED }
    public fun status_executed(): u8 { STATUS_EXECUTED }
    public fun status_expired(): u8 { STATUS_EXPIRED }
}
