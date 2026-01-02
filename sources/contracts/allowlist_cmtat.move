/// Allowlist CMTAT - CMTAT with Allowlist Functionality using IOTA Native Tokens
/// All Light features plus allowlist control and partial token freezing
/// Uses capability-based access control and Coin<CMTAT> architecture
module move_cmtat::allowlist_cmtat {
    use std::string::String;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::clock::{Self, Clock};

    use move_cmtat::base;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::allowlist;
    use move_cmtat::rule_engine;
    use move_cmtat::snapshot_engine;
    use move_cmtat::icmtat;

    /// Errors
    const EUnauthorized: u64 = 2000;
    const EInsufficientBalance: u64 = 2001;
    const EInvalidAmount: u64 = 2002;
    const ETransferRestricted: u64 = 2003;

    /// Allowlist CMTAT Token shared object
    public struct AllowlistCMTAT has key {
        id: UID,
        token_info: base::TokenInfo,
        treasury_cap: TreasuryCap<base::CMTAT>,
        snapshot_engine: snapshot_engine::SnapshotEngine,
        document_uri: String,
    }

    /// Shared compliance state object
    public struct ComplianceState has key {
        id: UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        allowlist_state: allowlist::AllowlistState,
    }

    /// Capability structs for access control
    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct FreezeCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }
    public struct AllowlistCap has key, store { id: UID }
    public struct SnapshotCap has key, store { id: UID }

    /// Initialize Allowlist CMTAT with native IOTA token architecture
    public entry fun init_token(
        name: String,
        symbol: String,
        decimals: u8,
        initial_supply: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Create token metadata
        let token_info = base::init_token_info(name, symbol, decimals, ctx);

        // Create treasury cap
        let treasury_cap = base::create_treasury_cap(ctx);

        // Mint initial supply if specified
        let initial_coins = if (initial_supply > 0) {
            base::mint(&mut treasury_cap, initial_supply, ctx)
        } else {
            coin::zero<base::CMTAT>(ctx)
        };

        // Create token object
        let token = AllowlistCMTAT {
            id: object::new(ctx),
            token_info,
            treasury_cap,
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
            document_uri: std::string::utf8(b""),
        };

        // Create compliance state
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
            allowlist_state: allowlist::init_allowlist_state(ctx),
        };

        // Create capability objects
        let admin = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };
        let allowlist_cap = AllowlistCap { id: object::new(ctx) };
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };

        // Share objects
        transfer::share_object(token);
        transfer::share_object(compliance_state);

        // Transfer capabilities to admin
        transfer::transfer(admin_cap, admin);
        transfer::transfer(mint_cap, admin);
        transfer::transfer(burn_cap, admin);
        transfer::transfer(freeze_cap, admin);
        transfer::transfer(pause_cap, admin);
        transfer::transfer(allowlist_cap, admin);
        transfer::transfer(snapshot_cap, admin);

        // Transfer initial coins to recipient
        if (initial_supply > 0) {
            transfer::transfer(initial_coins, recipient);
        } else {
            base::destroy_zero_coin(initial_coins);
        }
    }

    // ============ Role Management ============

    fun grant_role_internal(token: &mut AllowlistCMTAT, account: address, role: vector<u8>) {
        if (!table::contains(&token.roles, account)) {
            table::add(&mut token.roles, account, vector::empty());
        };
        let roles = table::borrow_mut(&mut token.roles, account);
        vector::push_back(roles, role);
    }

    fun has_role(token: &AllowlistCMTAT, account: address, role: vector<u8>): bool {
        if (!table::contains(&token.roles, account)) {
            return false
        };
        let roles = table::borrow(&token.roles, account);
        vector::contains(roles, &role)
    }

    fun require_role(token: &AllowlistCMTAT, account: address, role: vector<u8>) {
        assert!(has_role(token, account, role), EUnauthorized);
    }

    // ============ View Functions ============

    public fun name(token: &AllowlistCMTAT): String {
        base::name(&token.token_info)
    }

    public fun symbol(token: &AllowlistCMTAT): String {
        base::symbol(&token.token_info)
    }

    public fun decimals(token: &AllowlistCMTAT): u8 {
        base::decimals(&token.token_info)
    }

    public fun total_supply(token: &AllowlistCMTAT): u64 {
        base::total_supply(&token.token_info)
    }

    public fun balance_of(token: &AllowlistCMTAT, account: address): u64 {
        base::balance_of(&token.balances, account)
    }

    public fun get_active_balance_of(token: &AllowlistCMTAT, account: address): u64 {
        let total_balance = base::balance_of(&token.balances, account);
        freeze::get_active_balance(total_balance, &token.freeze_state, account)
    }

    public fun paused(compliance_state: &ComplianceState): bool {
        pause::is_paused(&compliance_state.pause_state)
    }

    public fun is_frozen(compliance_state: &ComplianceState, account: address): bool {
        freeze::is_frozen(&compliance_state.freeze_state, account)
    }

    public fun is_allowlisted(compliance_state: &ComplianceState, account: address): bool {
        allowlist::is_allowlisted(&compliance_state.allowlist_state, account)
    }

    public fun allowlist_enabled(token: &AllowlistCMTAT): bool {
        allowlist::is_enabled(&token.allowlist_state)
    }

    public fun document_uri(token: &AllowlistCMTAT): String {
        token.document_uri
    }

    // ============ Administrative Functions ============

    public entry fun set_terms(
        token: &mut AllowlistCMTAT,
        new_terms: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_terms(&mut token.token_info, new_terms);
    }

    public entry fun set_information(
        token: &mut AllowlistCMTAT,
        new_info: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_information(&mut token.token_info, new_info);
    }

    public entry fun set_token_id(
        token: &mut AllowlistCMTAT,
        new_id: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::extra_information_role());
        base::set_token_id(&mut token.token_info, new_id);
    }

    public entry fun set_document_uri(
        token: &mut AllowlistCMTAT,
        uri: String,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::document_role());
        token.document_uri = uri;
    }

    // ============ Minting Functions ============

    public entry fun mint(
        _mint_cap: &MintCap,
        token: &mut AllowlistCMTAT,
        compliance_state: &ComplianceState,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);
        allowlist::require_allowlisted(&compliance_state.allowlist_state, to);

        let coins = base::mint(&mut token.treasury_cap, amount, ctx);
        base::transfer_coin(coins, to);
    }

    public entry fun batch_mint(
        token: &mut AllowlistCMTAT,
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
            allowlist::require_allowlisted(&token.allowlist_state, recipient);
            
            let current_balance = base::balance_of(&token.balances, recipient);
            base::update_balance(&mut token.balances, recipient, current_balance + amount);
            base::increase_total_supply(&mut token.token_info, amount);
            
            i = i + 1;
        }
    }

    // ============ Burning Functions ============

    public entry fun burn(
        token: &mut AllowlistCMTAT,
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
        token: &mut AllowlistCMTAT,
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
        token: &mut AllowlistCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::pause(&mut token.pause_state);
    }

    public entry fun unpause(
        token: &mut AllowlistCMTAT,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::pauser_role());
        pause::unpause(&mut token.pause_state);
    }

    // ============ Freeze Functions ============

    public entry fun set_address_frozen(
        token: &mut AllowlistCMTAT,
        account: address,
        frozen: bool,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        freeze::set_address_frozen(&mut token.freeze_state, account, frozen);
    }

    public entry fun freeze_partial_tokens(
        token: &mut AllowlistCMTAT,
        account: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::erc20enforcer_role());
        freeze::freeze_partial_tokens(&mut token.freeze_state, account, amount);
    }

    public entry fun unfreeze_partial_tokens(
        token: &mut AllowlistCMTAT,
        account: address,
        amount: u64,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::erc20enforcer_role());
        freeze::unfreeze_partial_tokens(&mut token.freeze_state, account, amount);
    }

    // ============ Allowlist Functions ============

    public entry fun enable_allowlist(
        token: &mut AllowlistCMTAT,
        enabled: bool,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        allowlist::set_enabled(&mut token.allowlist_state, enabled);
    }

    public entry fun set_address_allowlist(
        token: &mut AllowlistCMTAT,
        account: address,
        status: bool,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        allowlist::set_address_allowlist(&mut token.allowlist_state, account, status);
    }

    public entry fun batch_set_address_allowlist(
        token: &mut AllowlistCMTAT,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::enforcer_role());
        allowlist::batch_set_address_allowlist(&mut token.allowlist_state, accounts, statuses);
    }

    // ============ Snapshot Functions ============

    public entry fun schedule_snapshot(
        token: &mut AllowlistCMTAT,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        require_role(token, tx_context::sender(ctx), icmtat::snapshooter_role());
        
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = base::total_supply(&token.token_info);
        
        snapshot_engine::create_snapshot(&mut token.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ============ Transfer Functions ============

    /// Transfer function with CMTAT compliance validation including allowlist
    public entry fun transfer(
        compliance_state: &ComplianceState,
        coins: Coin<base::CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = base::coin_value(&coins);

        // Validate transfer using rule engine with allowlist
        let restriction_code = rule_engine::validate_transfer_with_allowlist(
            &compliance_state.pause_state,
            &compliance_state.freeze_state,
            &compliance_state.allowlist_state,
            from,
            to,
            amount,
            amount  // from_balance is the coin value being transferred
        );

        assert!(restriction_code == icmtat::restriction_code_valid(), ETransferRestricted);

        // Transfer the coins
        base::transfer_coin(coins, to);
    }
}
