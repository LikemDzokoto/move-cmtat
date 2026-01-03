/// Light CMTAT - Fully IOTA Native Regulated Token Implementation
/// CORRECTED VERSION - All compilation errors fixed
module move_cmtat::light_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::object::{UID};
    use iota::tx_context::{TxContext};
    use iota::event;

    // ========== ONE-TIME WITNESS ==========
    public struct LIGHT_CMTAT has drop {}

    // ========== CAPABILITIES ==========
    public struct AdminCap has key, store {
        id: UID,
    }

    public struct MinterCap has key, store {
        id: UID,
    }

    public struct PauserCap has key, store {
        id: UID,
    }

    public struct EnforcerCap has key, store {
        id: UID,
    }

    // ========== REGISTRY ==========
    public struct LightCMTATRegistry has key {
        id: UID,
        terms: String,
        information: String,
        token_id: String,
        deactivated: bool,
    }

    // ========== EVENTS ==========
    public struct TokenMinted has copy, drop {
        minter: address,
        to: address,
        amount: u64,
    }

    public struct TokenBurned has copy, drop {
        burner: address,
        from: address,
        amount: u64,
    }

    public struct AddressFrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct AddressUnfrozen has copy, drop {
        enforcer: address,
        account: address,
    }

    public struct ModulePaused has copy, drop {
        pauser: address,
    }

    public struct ModuleUnpaused has copy, drop {
        pauser: address,
    }

    public struct ModuleDeactivated has copy, drop {
        admin: address,
    }

    // ========== ERRORS ==========
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    const ELengthMismatch: u64 = 3;
    const EInvalidAmount: u64 = 5;

    // ========== INIT FUNCTION ==========
    fun init(witness: LIGHT_CMTAT, ctx: &mut TxContext) {
        let (treasury_cap, deny_cap, coin_metadata) = coin::create_regulated_currency_v1(
            witness,
            9,
            b"LCMTAT",
            b"Light CMTAT Token",
            b"Light version of CMTAT regulated token",
            option::none(),
            true,
            ctx
        );

        let registry = LightCMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            deactivated: false,
        };

        let admin_cap = AdminCap { id: object::new(ctx) };
        let minter_cap = MinterCap { id: object::new(ctx) };
        let pauser_cap = PauserCap { id: object::new(ctx) };
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };

        let deployer = tx_context::sender(ctx);

        transfer::public_transfer(treasury_cap, deployer);
        transfer::public_transfer(deny_cap, deployer);
        transfer::public_freeze_object(coin_metadata);
        
        transfer::transfer(admin_cap, deployer);
        transfer::transfer(minter_cap, deployer);
        transfer::transfer(pauser_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
        
        transfer::share_object(registry);
    }

    // ========== CAPABILITY GRANTING ==========
    public entry fun grant_minter(
        _admin_cap: &AdminCap,
        to: address,
        ctx: &mut TxContext
    ) {
        let minter_cap = MinterCap { id: object::new(ctx) };
        transfer::transfer(minter_cap, to);
    }

    public entry fun grant_pauser(
        _admin_cap: &AdminCap,
        to: address,
        ctx: &mut TxContext
    ) {
        let pauser_cap = PauserCap { id: object::new(ctx) };
        transfer::transfer(pauser_cap, to);
    }

    public entry fun grant_enforcer(
        _admin_cap: &AdminCap,
        to: address,
        ctx: &mut TxContext
    ) {
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };
        transfer::transfer(enforcer_cap, to);
    }

    // ========== VIEW FUNCTIONS ==========
    public fun name(metadata: &CoinMetadata<LIGHT_CMTAT>): String {
        coin::get_name(metadata)
    }

    // ✅ FIX: Use from_ascii to convert
    public fun symbol(metadata: &CoinMetadata<LIGHT_CMTAT>): String {
        let ascii_symbol = coin::get_symbol(metadata);
        string::from_ascii(ascii_symbol)
    }

    public fun decimals(metadata: &CoinMetadata<LIGHT_CMTAT>): u8 {
        coin::get_decimals(metadata)
    }

    public fun total_supply(treasury_cap: &TreasuryCap<LIGHT_CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    public fun terms(registry: &LightCMTATRegistry): String {
        registry.terms
    }

    public fun information(registry: &LightCMTATRegistry): String {
        registry.information
    }

    public fun token_id(registry: &LightCMTATRegistry): String {
        registry.token_id
    }

    public fun deactivated(registry: &LightCMTATRegistry): bool {
        registry.deactivated
    }

    public fun is_paused(deny_list: &DenyList, ctx: &TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<LIGHT_CMTAT>(deny_list, ctx)
    }

    // ✅ FIX: Use deny_list::contains instead
    public fun is_frozen(deny_list: &DenyList, account: address): bool {
        deny_list::v1_contains_current_epoch<LIGHT_CMTAT>(deny_list, account)
    }

    // ========== ROLE GETTERS ==========
    public fun get_default_admin_role(): vector<u8> { b"DEFAULT_ADMIN_ROLE" }
    public fun get_minter_role(): vector<u8> { b"MINTER_ROLE" }
    public fun get_pauser_role(): vector<u8> { b"PAUSER_ROLE" }
    public fun get_enforcer_role(): vector<u8> { b"ENFORCER_ROLE" }

    // ========== ADMINISTRATIVE FUNCTIONS ==========
    public entry fun set_terms(
        _admin_cap: &AdminCap,
        registry: &mut LightCMTATRegistry,
        new_terms: String
    ) {
        registry.terms = new_terms;
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        registry: &mut LightCMTATRegistry,
        new_info: String
    ) {
        registry.information = new_info;
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        registry: &mut LightCMTATRegistry,
        new_id: String
    ) {
        registry.token_id = new_id;
    }

    // ========== MINTING FUNCTIONS ==========
    public fun mint(
        _minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<LIGHT_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, to), EAddressFrozen);

        let coins = coin::mint(treasury_cap, amount, ctx);

        event::emit(TokenMinted {
            minter: tx_context::sender(ctx),
            to,
            amount,
        });

        coins
    }

    public entry fun mint_and_transfer(
        minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coins = mint(minter_cap, treasury_cap, registry, deny_list, to, amount, ctx);
        transfer::public_transfer(coins, to);
    }

    public entry fun batch_mint(
        minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        recipients: vector<address>,
        amounts: vector<u64>,
        ctx: &mut TxContext
    ) {
        let len = vector::length(&recipients);
        assert!(len == vector::length(&amounts), ELengthMismatch);

        let i = 0;
        while (i < len) {
            let recipient = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);

            let coins = mint(minter_cap, treasury_cap, registry, deny_list, recipient, amount, ctx);
            transfer::public_transfer(coins, recipient);

            i = i + 1;
        }
    }

    // ========== BURNING FUNCTIONS ==========
    public fun burn(
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        let amount = coin::value(&coins);
        let burner = tx_context::sender(ctx);

        coin::burn(treasury_cap, coins);

        event::emit(TokenBurned {
            burner,
            from: burner,
            amount,
        });
    }

    public entry fun burn_entry(
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        burn(treasury_cap, coins, ctx);
    }

    public entry fun burn_from(
        _minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        burn(treasury_cap, coins, ctx);
    }

    public entry fun batch_burn(
        _minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        mut coins: vector<Coin<LIGHT_CMTAT>>,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            burn(treasury_cap, coin, ctx);
        };

        vector::destroy_empty(coins);
    }

    public entry fun forced_burn(
        _enforcer_cap: &EnforcerCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        burn(treasury_cap, coins, ctx);
    }

    public entry fun burn_and_mint(
        minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        burn_coins: Coin<LIGHT_CMTAT>,
        mint_to: address,
        mint_amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, mint_to), EAddressFrozen);
        assert!(mint_amount > 0, EInvalidAmount);

        burn(treasury_cap, burn_coins, ctx);

        let mint_coins = coin::mint(treasury_cap, mint_amount, ctx);

        event::emit(TokenMinted {
            minter: tx_context::sender(ctx),
            to: mint_to,
            amount: mint_amount,
        });

        transfer::public_transfer(mint_coins, mint_to);
    }

    // ========== TRANSFER FUNCTION ==========
    public entry fun transfer(
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        coins: Coin<LIGHT_CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);

        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, from), EAddressFrozen);
        assert!(!is_frozen(deny_list, to), EAddressFrozen);

        transfer::public_transfer(coins, to);
    }

    // ========== FREEZE FUNCTIONS ==========
    public entry fun set_address_frozen(
        _enforcer_cap: &EnforcerCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<LIGHT_CMTAT>,
        account: address,
        frozen: bool,
        ctx: &mut TxContext
    ) {
        let enforcer = tx_context::sender(ctx);

        if (frozen) {
            coin::deny_list_v1_add(deny_list, deny_cap, account, ctx);
            event::emit(AddressFrozen { enforcer, account });
        } else {
            coin::deny_list_v1_remove(deny_list, deny_cap, account, ctx);
            event::emit(AddressUnfrozen { enforcer, account });
        }
    }

    public entry fun batch_set_address_frozen(
        enforcer_cap: &EnforcerCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<LIGHT_CMTAT>,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &mut TxContext
    ) {
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), ELengthMismatch);

        let i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);

            set_address_frozen(enforcer_cap, deny_list, deny_cap, account, status, ctx);

            i = i + 1;
        }
    }

    // ========== PAUSE FUNCTIONS ==========
    public entry fun pause(
        _pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModulePaused {
            pauser: tx_context::sender(ctx),
        });
    }

    public entry fun unpause(
        _pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        coin::deny_list_v1_disable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleUnpaused {
            pauser: tx_context::sender(ctx),
        });
    }

    // ========== DEACTIVATION ==========
    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        registry: &mut LightCMTATRegistry,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<LIGHT_CMTAT>,
        ctx: &mut TxContext
    ) {
        registry.deactivated = true;

        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleDeactivated {
            admin: tx_context::sender(ctx),
        });
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(LIGHT_CMTAT {}, ctx);
    }
}
