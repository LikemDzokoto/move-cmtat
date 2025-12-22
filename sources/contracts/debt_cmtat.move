/// Debt CMTAT - CMTAT for Debt Securities
/// Specialized for corporate bonds and debt instruments
/// Implements 10 roles including DEBT_ROLE
module move_cmtat::debt_cmtat {
    use std::string::String;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::table::{Self, Table};
    use iota::clock::{Self, Clock};
    
    use move_cmtat::base;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::debt;
    use move_cmtat::snapshot_engine;
    use move_cmtat::icmtat;

    /// Errors
    const EUnauthorized: u64 = 3000;
    const EInsufficientBalance: u64 = 3001;
    const EInvalidAmount: u64 = 3002;
    const EInDefault: u64 = 3003;

    /// Debt CMTAT Token
    public struct DebtCMTAT has key, store {
        id: UID,
        token_info: base::TokenInfo,
        balances: base::Balances,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        debt_state: debt::DebtState,
        snapshot_engine: snapshot_engine::SnapshotEngine,
        roles: Table<address, vector<vector<u8>>>,  // address -> list of roles
        document_uri: String,
    }

    /// Admin capability
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Initialize Debt CMTAT
    public entry fun init_token(
        name: String,
        symbol: String,
        decimals: u8,
        initial_supply: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let token = DebtCMTAT {
            id: object::new(ctx),
            token_info: base::init_token_info(name, symbol, decimals, ctx),
            balances: base::init_balances(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
            debt_state: debt::init_debt_state(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
            roles: table::new(ctx),
            document_uri: std::string::utf8(b""),
        };

        // Mint initial supply to recipient
        if (initial_supply > 0) {
            base::update_balance(&mut token.balances, recipient, initial_supply);
            base::increase_total_supply(&mut token.token_info, initial_supply);
        };

        // Grant all roles to admin (10 roles for debt CMTAT)
        let admin = tx_context::sender(ctx);
        grant_role_internal(&mut token, admin, icmtat::default_admin_role());
        grant_role_internal(&mut token, admin, icmtat::minter_role());
        grant_role_internal(&mut token, admin, icmtat::pauser_role());
        grant_role_internal(&mut token, admin, icmtat::enforcer_role());
        grant_role_internal(&mut token, admin, icmtat::erc20enforcer_role());
        grant_role_internal(&mut token, admin, icmtat::snapshooter_role());
        grant_role_internal(&mut token, admin, icmtat::document_role());
        grant_role_internal(&mut token, admin, icmtat::extra_information_role());
        grant_role_internal(&mut token, admin, icmtat::debt_role());

        // Create and transfer admin capability
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::share_object(token);
        transfer::transfer(admin_cap, admin);
    }

    // ============ Role Management ============

    fun grant_role_internal(token: &mut DebtCMTAT, account: address, role: vector<u8>) {
        if (!table::contains(&token.roles, account)) {
            table::add(&mut token.roles, account, vector::empty());
        };
        let roles = table::borrow_mut(&mut token.roles, account);
        vector::push_back(roles, role);
    }

    fun has_role(token: &DebtCMTAT, account: address, role: vector<u8>): bool {
        if (!table::contains(&token.roles, account)) {
            return false
        };
        let roles = table::borrow(&token.roles, account);
        vector::contains(roles, &role)
    }

    fun require_role(token: &DebtCMTAT, account: address, role: vector<u8>) {
        assert!(has_role(token, account, role), EUnauthorized);
    }

    // ============ View Functions ============

    public fun name(token: &DebtCMTAT): String {
        base::name(&token.token_info)
    }

    public fun symbol(token: &DebtCMTAT): String {
        base::symbol(&token.token_info)
    }

    public fun decimals(token: &DebtCMTAT): u8 {
        base::decimals(&token.token_info)
    }

    public fun total_supply(token: &DebtCMTAT): u64 {
        base::total_supply(&token.token_info)
    }

    public fun balance_of(token: &DebtCMTAT, account: address): u64 {
        base::balance_of(&token.balances, account)
    }

    public fun get_active_balance_of(token: &DebtCMTAT, account: address): u64 {
        let total_balance = base::balance_of(&token.balances, account);
        freeze::get_active_balance(total_balance, &token.freeze_state, account)
    }

    public fun paused(token: &DebtCMTAT): bool {
        pause::is_paused(&token.pause_state)
    }

    public fun is_frozen(token: &DebtCMTAT, account: address): bool {
        freeze::is_frozen(&token.freeze_state, account)
    }

    public fun debt(token: &DebtCMTAT): String {
        debt::get_debt(&token.debt_state)
    }

    public fun credit_events(token: &DebtCMTAT): String {
        debt::get_credit_events(&token.debt_state)
    }

    public fun debt_engine(token: &DebtCMTAT): address {
        debt::get_debt_engine(&token.debt_state)
    }

    public fun is_default_flagged(token: &DebtCMTAT): bool {
        debt::is_default_flagged(&token.debt_state)
    }

    public fun document_uri(token: &DebtCMTAT): String {
        token.document_uri
    }

    // ============ Administrative Functions ============

    public entry fun set_terms(
        token: &mut DebtCMTAT,
        new_terms: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_terms(&mut token.token_info, new_terms);
    }

    public entry fun set_information(
        token: &mut DebtCMTAT,
        new_info: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_information(&mut token.token_info, new_info);
    }

    public entry fun set_token_id(
        token: &mut DebtCMTAT,
        new_id: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_token_id(&mut token.token_info, new_id);
    }

    public entry fun set_document_uri(
        token: &mut DebtCMTAT,
        uri: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::document_role());
        token.document_uri = uri;
    }

    // ============ Debt-Specific Functions ============

    public entry fun set_debt(
        token: &mut DebtCMTAT,
        debt_info: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::debt_role());
        debt::set_debt(&mut token.debt_state, debt_info);
    }

    public entry fun set_credit_events(
        token: &mut DebtCMTAT,
        events: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::debt_role());
        debt::set_credit_events(&mut token.debt_state, events);
    }

    public entry fun set_debt_engine(
        token: &mut DebtCMTAT,
        engine: address,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::debt_role());
        debt::set_debt_engine(&mut token.debt_state, engine);
    }

    public entry fun flag_default(
        token: &mut DebtCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::debt_role());
        debt::flag_default(&mut token.debt_state);
    }

    // ============ Minting Functions ============

    public entry fun mint(
        token: &mut DebtCMTAT,
        to: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        freeze::require_not_frozen(&token.freeze_state, to);
        debt::require_not_in_default(&token.debt_state);

        let current_balance = base::balance_of(&token.balances, to);
        base::update_balance(&mut token.balances, to, current_balance + amount);
        base::increase_total_supply(&mut token.token_info, amount);
    }

    public entry fun batch_mint(
        token: &mut DebtCMTAT,
        recipients: vector<address>,
        amounts: vector<u64>,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        debt::require_not_in_default(&token.debt_state);
        
        let i = 0;
        let len = vector::length(&recipients);
        assert!(len == vector::length(&amounts), EInvalidAmount);

        while (i < len) {
            let recipient = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            
            freeze::require_not_frozen(&token.freeze_state, recipient);
            
            let current_balance = base::balance_of(&token.balances, recipient);
            base::update_balance(&mut token.balances, recipient, current_balance + amount);
            base::increase_total_supply(&mut token.token_info, amount);
            
            i = i + 1;
        }
    }

    // ============ Burning Functions ============

    public entry fun burn(
        token: &mut DebtCMTAT,
        amount: u64,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        pause::require_not_paused(&token.pause_state);
        
        let balance = base::balance_of(&token.balances, sender);
        assert!(balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, sender, balance - amount);
        base::decrease_total_supply(&mut token.token_info, amount);
    }

    public entry fun burn_from(
        token: &mut DebtCMTAT,
        from: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);

        let balance = base::balance_of(&token.balances, from);
        assert!(balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, from, balance - amount);
        base::decrease_total_supply(&mut token.token_info, amount);
    }

    // ============ Pause Functions ============

    public entry fun pause(
        token: &mut DebtCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::pause(&mut token.pause_state);
    }

    public entry fun unpause(
        token: &mut DebtCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::unpause(&mut token.pause_state);
    }

    // ============ Freeze Functions ============

    public entry fun set_address_frozen(
        token: &mut DebtCMTAT,
        account: address,
        frozen: bool,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        freeze::set_address_frozen(&mut token.freeze_state, account, frozen);
    }

    public entry fun freeze_partial_tokens(
        token: &mut DebtCMTAT,
        account: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::erc20enforcer_role());
        freeze::freeze_partial_tokens(&mut token.freeze_state, account, amount);
    }

    public entry fun unfreeze_partial_tokens(
        token: &mut DebtCMTAT,
        account: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::erc20enforcer_role());
        freeze::unfreeze_partial_tokens(&mut token.freeze_state, account, amount);
    }

    // ============ Snapshot Functions ============

    public entry fun schedule_snapshot(
        token: &mut DebtCMTAT,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::snapshooter_role());
        
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = base::total_supply(&token.token_info);
        
        snapshot_engine::create_snapshot(&mut token.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ============ Transfer Functions ============

    public entry fun transfer(
        token: &mut DebtCMTAT,
        to: address,
        amount: u64,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        pause::require_not_paused(&token.pause_state);
        freeze::require_not_frozen(&token.freeze_state, sender);
        freeze::require_not_frozen(&token.freeze_state, to);

        let sender_balance = base::balance_of(&token.balances, sender);
        let active_balance = freeze::get_active_balance(sender_balance, &token.freeze_state, sender);
        assert!(active_balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, sender, sender_balance - amount);
        
        let to_balance = base::balance_of(&token.balances, to);
        base::update_balance(&mut token.balances, to, to_balance + amount);
    }
}
