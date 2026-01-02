/// Light CMTAT - Minimal CMTAT Implementation using IOTA Native Tokens
/// Basic compliance features with capability-based access control
/// Uses Coin<CMTAT> for user balances, TreasuryCap<CMTAT> for mint/burn authority
module move_cmtat::light_cmtat {
    use std::string::String;
    use iota::coin::{Self, Coin, TreasuryCap};
    
    use move_cmtat::base;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::rule_engine;
    use move_cmtat::icmtat;

    /// Errors
    const ETransferRestricted: u64 = 1003;

    /// Light CMTAT Token shared object (contains metadata and TreasuryCap)
    public struct LightCMTAT has key {
        id: UID,
        token_info: base::TokenInfo,
        treasury_cap: TreasuryCap<base::CMTAT>,
    }

    /// Shared compliance state object
    public struct ComplianceState has key {
        id: UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
    }

    /// Capability structs for access control (transferable objects)
    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct FreezeCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }

    /// Initialize Light CMTAT with native IOTA token architecture
    /// Creates TreasuryCap<CMTAT>, mints initial supply, and distributes capabilities
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

        // Create treasury cap for mint/burn authority
        let treasury_cap = base::create_treasury_cap(ctx);

        // Mint initial supply if specified
        let initial_coins = if (initial_supply > 0) {
            base::mint(&mut treasury_cap, initial_supply, ctx)
        } else {
            coin::zero<base::CMTAT>(ctx)
        };

        // Create token object
        let token = LightCMTAT {
            id: object::new(ctx),
            token_info,
            treasury_cap,
        };

        // Create compliance state
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
        };

        // Create capability objects
        let admin = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };

        // Share objects
        transfer::share_object(token);
        transfer::share_object(compliance_state);

        // Transfer capabilities to admin
        transfer::transfer(admin_cap, admin);
        transfer::transfer(mint_cap, admin);
        transfer::transfer(burn_cap, admin);
        transfer::transfer(freeze_cap, admin);
        transfer::transfer(pause_cap, admin);

        // Transfer initial coins to recipient (if any)
        if (initial_supply > 0) {
            transfer::public_transfer(initial_coins, recipient);
        } else {
            // Destroy zero coin
            base::destroy_zero_coin(initial_coins);
        }
    }

    // ============ Capability-Based Access Control ============

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
        base::total_supply(&token.treasury_cap)
    }

    /// Note: balance_of is now handled by coin::value() on user's Coin<CMTAT> objects
    /// This function is kept for compatibility but returns 0 (use wallet/indexer to query balances)
    public fun balance_of(_token: &LightCMTAT, _account: address): u64 {
        0  // Balances are in Coin<CMTAT> objects owned by users
    }

    /// Note: batch_balance_of is now handled by querying multiple Coin<CMTAT> objects
    public fun batch_balance_of(_token: &LightCMTAT, _accounts: vector<address>): vector<u64> {
        vector::empty()  // Balances are in Coin<CMTAT> objects owned by users
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

    public fun paused(compliance_state: &ComplianceState): bool {
        pause::is_paused(&compliance_state.pause_state)
    }

    public fun deactivated(compliance_state: &ComplianceState): bool {
        pause::is_deactivated(&compliance_state.pause_state)
    }

    public fun is_frozen(compliance_state: &ComplianceState, account: address): bool {
        freeze::is_frozen(&compliance_state.freeze_state, account)
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
        _admin_cap: &AdminCap,
        token: &mut LightCMTAT,
        new_terms: String
    ) {
        base::set_terms(&mut token.token_info, new_terms);
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        token: &mut LightCMTAT,
        new_info: String
    ) {
        base::set_information(&mut token.token_info, new_info);
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        token: &mut LightCMTAT,
        new_id: String
    ) {
        base::set_token_id(&mut token.token_info, new_id);
    }

    // ============ Minting Functions ============

    public entry fun mint(
        _mint_cap: &MintCap,
        token: &mut LightCMTAT,
        compliance_state: &ComplianceState,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);

        let coins = base::mint(&mut token.treasury_cap, amount, ctx);
        base::transfer_coin(coins, to);
     }

    // ============ Burning Functions ============

    /// Burn coins provided by the user
    public entry fun burn(
        token: &mut LightCMTAT,
        coins: Coin<base::CMTAT>,
        compliance_state: &ComplianceState
    ) {
        pause::require_not_paused(&compliance_state.pause_state);
        base::burn(&mut token.treasury_cap, coins);
    }

    // ============ Pause Functions ============

    public entry fun pause(
        _pause_cap: &PauseCap,
        compliance_state: &mut ComplianceState
    ) {
        pause::pause(&mut compliance_state.pause_state);
    }

    public entry fun unpause(
        _pause_cap: &PauseCap,
        compliance_state: &mut ComplianceState
    ) {
        pause::unpause(&mut compliance_state.pause_state);
    }

    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        compliance_state: &mut ComplianceState
    ) {
        pause::deactivate(&mut compliance_state.pause_state);
    }

    // ============ Freeze Functions ============

    public entry fun set_address_frozen(
        _freeze_cap: &FreezeCap,
        compliance_state: &mut ComplianceState,
        account: address,
        frozen: bool
    ) {
        freeze::set_address_frozen(&mut compliance_state.freeze_state, account, frozen);
     }

    // ============ Transfer Functions ============

    /// Transfer function with CMTAT compliance validation
    /// Users call this to transfer their Coin<CMTAT> with regulatory checks
    public entry fun transfer(
        compliance_state: &ComplianceState,
        coins: Coin<base::CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = base::coin_value(&coins);

        // Validate transfer using rule engine
        let restriction_code = rule_engine::validate_transfer(
            &compliance_state.pause_state,
            &compliance_state.freeze_state,
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
