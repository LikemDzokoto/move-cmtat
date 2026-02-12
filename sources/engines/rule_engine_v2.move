/// RuleEngine V2 - CMTA-Compliant Rule Orchestration Engine
/// Implements hierarchical rule validation with VIP support and conditional transfers
module move_cmtat::rule_engine_v2 {

    use iota::table::{Self, Table};
    use iota::vec_map::{Self, VecMap};
    use iota::clock::Clock;
    use iota::event;
    use std::string::{Self, String};
    use std::option::Option;

    // ============ RULE TYPES ============
    const RULE_NONE: u8 = 0;
    const RULE_WHITELIST: u8 = 1;
    const RULE_CONDITIONAL_TRANSFER: u8 = 2;
    const RULE_BLACKLIST: u8 = 3;
    const RULE_SANCTION_LIST: u8 = 4;

    // ============ STATUS CONSTANTS ============
    const STATUS_NONE: u8 = 0;
    const STATUS_WAITING: u8 = 1;
    const STATUS_APPROVED: u8 = 2;
    const STATUS_DENIED: u8 = 3;
    const STATUS_EXECUTED: u8 = 4;

    // ============ RESTRICTION CODES ============
    const CODE_VALID: u8 = 0;
    const CODE_PAUSED: u8 = 1;
    const CODE_FROZEN_SENDER: u8 = 2;
    const CODE_FROZEN_RECEIVER: u8 = 3;
    const CODE_NOT_ALLOWLISTED: u8 = 4;
    const CODE_INSUFFICIENT_BALANCE: u8 = 5;
    const CODE_CONDITIONAL_REQUIRED: u8 = 10;
    const CODE_PENDING_APPROVAL: u8 = 11;
    const CODE_REQUEST_DENIED: u8 = 12;
    const CODE_REQUEST_EXPIRED: u8 = 13;
    const CODE_ALREADY_EXECUTED: u8 = 14;

    // ============ ERROR CODES ============
    const ERequestAlreadyExists: u64 = 600;
    const ERequestNotFound: u64 = 601;
    const ENotWaiting: u64 = 602;
    const ENotApproved: u64 = 603;
    const ERequestExpired: u64 = 604;
    const ENotOperator: u64 = 605;
    const ERuleNotFound: u64 = 606;
    const ETransferRestricted: u64 = 607;

    // ============ DEFAULT TIME LIMITS ============
    const DEFAULT_APPROVAL_DEADLINE_MS: u64 = 90 * 24 * 60 * 60 * 1000;
    const DEFAULT_EXECUTION_DEADLINE_MS: u64 = 30 * 24 * 60 * 60 * 1000;

    // ============ DATA STRUCTURES ============

    public struct TransferConfig has store, drop, copy {
        auto_approval_enabled: bool,
        approval_deadline_ms: u64,
        execution_deadline_ms: u64,
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
        rules: VecMap<u8, bool>,
        vip_list: Table<address, bool>,
        transfer_requests: Table<vector<u8>, TransferRequest>,
        request_counter: u64,
        config: TransferConfig,
        operator: address,
    }

    // ============ EVENTS ============

    public struct RuleAdded has copy, drop {
        operator: address,
        rule_type: u8,
    }

    public struct RuleRemoved has copy, drop {
        operator: address,
        rule_type: u8,
    }

    public struct VipAdded has copy, drop {
        operator: address,
        account: address,
    }

    public struct VipRemoved has copy, drop {
        operator: address,
        account: address,
    }

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

    // ============ INITIALIZATION ============

    public fun init_rule_engine_v2(
        ctx: &mut tx_context::TxContext
    ): RuleEngine {
        let engine = RuleEngine {
            id: object::new(ctx),
            rules: vec_map::empty(),
            vip_list: table::new(ctx),
            transfer_requests: table::new(ctx),
            request_counter: 0,
            config: TransferConfig {
                auto_approval_enabled: false,
                approval_deadline_ms: DEFAULT_APPROVAL_DEADLINE_MS,
                execution_deadline_ms: DEFAULT_EXECUTION_DEADLINE_MS,
            },
            operator: tx_context::sender(ctx),
        };
        engine
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

    // ============ RULE MANAGEMENT ============

    public fun is_rule_enabled(rule_engine: &RuleEngine, rule_type: u8): bool {
        vec_map::contains(&rule_engine.rules, &rule_type)
    }

    public entry fun add_rule(
        rule_engine: &mut RuleEngine,
        rule_type: u8,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (!vec_map::contains(&rule_engine.rules, &rule_type)) {
            vec_map::insert(&mut rule_engine.rules, rule_type, true);
        };

        event::emit(RuleAdded { operator, rule_type });
    }

    public entry fun remove_rule(
        rule_engine: &mut RuleEngine,
        rule_type: u8,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (vec_map::contains(&rule_engine.rules, &rule_type)) {
            vec_map::remove(&mut rule_engine.rules, &rule_type);
        };

        event::emit(RuleRemoved { operator, rule_type });
    }

    // ============ VIP MANAGEMENT ============

    public fun is_vip(rule_engine: &RuleEngine, account: address): bool {
        table::contains(&rule_engine.vip_list, account)
    }

    public entry fun add_vip(
        rule_engine: &mut RuleEngine,
        account: address,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (!table::contains(&rule_engine.vip_list, account)) {
            table::add(&mut rule_engine.vip_list, account, true);
        };

        event::emit(VipAdded { operator, account });
    }

    public entry fun remove_vip(
        rule_engine: &mut RuleEngine,
        account: address,
        ctx: &tx_context::TxContext
    ) {
        let operator = tx_context::sender(ctx);
        assert!(operator == rule_engine.operator, ENotOperator);

        if (table::contains(&rule_engine.vip_list, account)) {
            table::remove(&mut rule_engine.vip_list, account);
        };

        event::emit(VipRemoved { operator, account });
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
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        is_allowlisted: bool
    ): u8 {
        let now = clock.timestamp_ms();

        // Step 1: Check VIP status (bypasses conditional transfer ONLY)
        if (is_vip(rule_engine, from) && is_vip(rule_engine, to)) {
            if (!is_allowlisted) {
                return CODE_NOT_ALLOWLISTED
            };
            return CODE_VALID
        };

        // Step 2: Check if conditional transfer rule is enabled
        if (is_rule_enabled(rule_engine, RULE_CONDITIONAL_TRANSFER)) {
            let code = validate_conditional_request(rule_engine, from, to, value, now);
            if (code != CODE_VALID) return code;
        };

        // Step 3: Allowlist check (always required)
        if (!is_allowlisted) {
            return CODE_NOT_ALLOWLISTED
        };

        CODE_VALID
    }

    fun validate_conditional_request(
        rule_engine: &RuleEngine,
        from: address,
        to: address,
        value: u64,
        now: u64
    ): u8 {
        let key = generate_request_key(from, to, value);

        if (!table::contains(&rule_engine.transfer_requests, key)) {
            return CODE_CONDITIONAL_REQUIRED
        };

        let request = table::borrow(&rule_engine.transfer_requests, key);

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
            _ => CODE_CONDITIONAL_REQUIRED,
        }
    }

    // ============ ERC-1404 INTERFACE ============

    public fun detect_transfer_restriction(
        rule_engine: &RuleEngine,
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        is_allowlisted: bool
    ): u8 {
        validate_transfer(rule_engine, from, to, value, clock, is_allowlisted)
    }

    public fun require_valid_transfer(
        rule_engine: &RuleEngine,
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        is_allowlisted: bool
    ) {
        let code = validate_transfer(rule_engine, from, to, value, clock, is_allowlisted);
        assert!(code == CODE_VALID, ETransferRestricted)
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
        from: address,
        to: address,
        value: u64,
        clock: &Clock,
        is_allowlisted: bool
    ): bool {
        let code = validate_transfer(rule_engine, from, to, value, clock, is_allowlisted);
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

    // ============ RULE TYPE GETTERS ============

    public fun rule_whitelist(): u8 { RULE_WHITELIST }
    public fun rule_conditional_transfer(): u8 { RULE_CONDITIONAL_TRANSFER }
    public fun rule_blacklist(): u8 { RULE_BLACKLIST }
    public fun rule_sanction_list(): u8 { RULE_SANCTION_LIST }
}
