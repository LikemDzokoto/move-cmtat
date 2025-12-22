/// Light CMTAT - Minimal CMTAT Implementation
/// Basic compliance features with 4 roles
/// Suitable for standard token deployments with simple regulatory requirements
module move_cmtat::light_cmtat {
    use std::string::String;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    
    use move_cmtat::base;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::icmtat;

    /// Errors
    const EUnauthorized: u64 = 1000;
    const EInsufficientBalance: u64 = 1001;
    const EInvalidAmount: u64 = 1002;

    /// Light CMTAT Token
    public struct LightCMTAT has key, store {
        id: UID,
        token_info: base::TokenInfo,
        balances: base::Balances,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        roles: Table<address, vector<vector<u8>>>,  // address -> list of roles
    }

    /// Admin capability
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Initialize Light CMTAT
    public entry fun init_token(
        name: String,
        symbol: String,
        decimals: u8,
        initial_supply: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let token = LightCMTAT {
            id: object::new(ctx),
            token_info: base::init_token_info(name, symbol, decimals, ctx),
            balances: base::init_balances(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
            roles: table::new(ctx),
        };

        // Mint initial supply to recipient
        if (initial_supply > 0) {
            base::update_balance(&mut token.balances, recipient, initial_supply);
            base::increase_total_supply(&mut token.token_info, initial_supply);
        };

        // Grant admin role to sender
        let admin = tx_context::sender(ctx);
        grant_role_internal(&mut token, admin, icmtat::default_admin_role());
        grant_role_internal(&mut token, admin, icmtat::minter_role());
        grant_role_internal(&mut token, admin, icmtat::pauser_role());
        grant_role_internal(&mut token, admin, icmtat::enforcer_role());

        // Create and transfer admin capability
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::share_object(token);
        transfer::transfer(admin_cap, admin);
    }

    // ============ Role Management ============

    /// Internal role grant
    fun grant_role_internal(token: &mut LightCMTAT, account: address, role: vector<u8>) {
        if (!table::contains(&token.roles, account)) {
            table::add(&mut token.roles, account, vector::empty());
        };
        let roles = table::borrow_mut(&mut token.roles, account);
        vector::push_back(roles, role);
    }

    /// Check if account has role
    fun has_role(token: &LightCMTAT, account: address, role: vector<u8>): bool {
        if (!table::contains(&token.roles, account)) {
            return false
        };
        let roles = table::borrow(&token.roles, account);
        vector::contains(roles, &role)
    }

    /// Require role
    fun require_role(token: &LightCMTAT, account: address, role: vector<u8>) {
        assert!(has_role(token, account, role), EUnauthorized);
    }

    // ============ View Functions ============

    public fun name(token: &LightCMTAT): String {
        base::name(&token.token_info)
    }

    public fun symbol(token: &LightCMTAT): String {
        base::symbol(&token.token_info)
    }

    public fun decimals(token: &LightCMTAT): u8 {
        base::decimals(&token.token_info)
    }

    public fun total_supply(token: &LightCMTAT): u64 {
        base::total_supply(&token.token_info)
    }

    public fun balance_of(token: &LightCMTAT, account: address): u64 {
        base::balance_of(&token.balances, account)
    }

    public fun batch_balance_of(token: &LightCMTAT, accounts: vector<address>): vector<u64> {
        base::batch_balance_of(&token.balances, accounts)
    }

    public fun terms(token: &LightCMTAT): String {
        base::terms(&token.token_info)
    }

    public fun information(token: &LightCMTAT): String {
        base::information(&token.token_info)
    }

    public fun token_id(token: &LightCMTAT): String {
        base::token_id(&token.token_info)
    }

    public fun paused(token: &LightCMTAT): bool {
        pause::is_paused(&token.pause_state)
    }

    public fun deactivated(token: &LightCMTAT): bool {
        pause::is_deactivated(&token.pause_state)
    }

    public fun is_frozen(token: &LightCMTAT, account: address): bool {
        freeze::is_frozen(&token.freeze_state, account)
    }

    // ============ Role Getters (matching Cairo ABI) ============

    public fun get_default_admin_role(): vector<u8> {
        icmtat::default_admin_role()
    }

    public fun get_minter_role(): vector<u8> {
        icmtat::minter_role()
    }

    public fun get_pauser_role(): vector<u8> {
        icmtat::pauser_role()
    }

    public fun get_enforcer_role(): vector<u8> {
        icmtat::enforcer_role()
    }

    // ============ Administrative Functions ============

    public entry fun set_terms(
        token: &mut LightCMTAT,
        new_terms: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::default_admin_role());
        base::set_terms(&mut token.token_info, new_terms);
    }

    public entry fun set_information(
        token: &mut LightCMTAT,
        new_info: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::default_admin_role());
        base::set_information(&mut token.token_info, new_info);
    }

    public entry fun set_token_id(
        token: &mut LightCMTAT,
        new_id: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::default_admin_role());
        base::set_token_id(&mut token.token_info, new_id);
    }

    // ============ Minting Functions ============

    public entry fun mint(
        token: &mut LightCMTAT,
        to: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        freeze::require_not_frozen(&token.freeze_state, to);

        let current_balance = base::balance_of(&token.balances, to);
        base::update_balance(&mut token.balances, to, current_balance + amount);
        base::increase_total_supply(&mut token.token_info, amount);
    }

    public entry fun batch_mint(
        token: &mut LightCMTAT,
        recipients: vector<address>,
        amounts: vector<u64>,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        
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
        token: &mut LightCMTAT,
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
        token: &mut LightCMTAT,
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

    public entry fun batch_burn(
        token: &mut LightCMTAT,
        accounts: vector<address>,
        amounts: vector<u64>,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        
        let i = 0;
        let len = vector::length(&accounts);
        assert!(len == vector::length(&amounts), EInvalidAmount);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let amount = *vector::borrow(&amounts, i);
            
            let balance = base::balance_of(&token.balances, account);
            assert!(balance >= amount, EInsufficientBalance);
            
            base::update_balance(&mut token.balances, account, balance - amount);
            base::decrease_total_supply(&mut token.token_info, amount);
            
            i = i + 1;
        }
    }

    public entry fun forced_burn(
        token: &mut LightCMTAT,
        from: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());

        let balance = base::balance_of(&token.balances, from);
        assert!(balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, from, balance - amount);
        base::decrease_total_supply(&mut token.token_info, amount);
    }

    public entry fun burn_and_mint(
        token: &mut LightCMTAT,
        from: address,
        to: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::minter_role());
        pause::require_not_paused(&token.pause_state);
        freeze::require_not_frozen(&token.freeze_state, to);
        
        let from_balance = base::balance_of(&token.balances, from);
        assert!(from_balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, from, from_balance - amount);
        
        let to_balance = base::balance_of(&token.balances, to);
        base::update_balance(&mut token.balances, to, to_balance + amount);
    }

    // ============ Pause Functions ============

    public entry fun pause(
        token: &mut LightCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::pause(&mut token.pause_state);
    }

    public entry fun unpause(
        token: &mut LightCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::unpause(&mut token.pause_state);
    }

    public entry fun deactivate_contract(
        token: &mut LightCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::default_admin_role());
        pause::deactivate(&mut token.pause_state);
    }

    // ============ Freeze Functions ============

    public entry fun set_address_frozen(
        token: &mut LightCMTAT,
        account: address,
        frozen: bool,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        freeze::set_address_frozen(&mut token.freeze_state, account, frozen);
    }

    public entry fun batch_set_address_frozen(
        token: &mut LightCMTAT,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        freeze::batch_set_address_frozen(&mut token.freeze_state, accounts, statuses);
    }

    // ============ Transfer Functions ============

    public entry fun transfer(
        token: &mut LightCMTAT,
        to: address,
        amount: u64,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        pause::require_not_paused(&token.pause_state);
        freeze::require_not_frozen(&token.freeze_state, sender);
        freeze::require_not_frozen(&token.freeze_state, to);

        let sender_balance = base::balance_of(&token.balances, sender);
        assert!(sender_balance >= amount, EInsufficientBalance);
        
        base::update_balance(&mut token.balances, sender, sender_balance - amount);
        
        let to_balance = base::balance_of(&token.balances, to);
        base::update_balance(&mut token.balances, to, to_balance + amount);
    }
}
