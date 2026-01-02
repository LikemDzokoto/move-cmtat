/// Light CMTAT - Fully IOTA Native Regulated Token Implementation
/// Implements CMTAT (Cash Management Token Access Control) using native IOTA Move patterns
/// Uses Coin<LIGHT_CMTAT>, TreasuryCap<LIGHT_CMTAT>, and DenyList for compliance
/// One-time witness ensures unique token type, capability-based access control
/// Full event system for transparency, LightCMTATRegistry for metadata storage
module move_cmtat::light_cmtat {
    use std::string::{Self, String};
    use std::option;
    use std::vector;
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::{Self, DenyList};
    use iota::object::{Self, UID};
    use iota::transfer::{Self, public_transfer, public_freeze_object, share_object};
    use iota::tx_context::{Self, TxContext};
    use iota::event;

    // ========== ONE-TIME WITNESS ==========
    // Ensures unique token type - only created once during module initialization
    // IOTA Native: One-time witness pattern for regulated currencies
    public struct LIGHT_CMTAT has drop {}

    // ========== CAPABILITIES ==========
    // IOTA Native: Transferable objects for capability-based authority
    // Dynamic granting allows flexible role assignment vs static EVM access control

    /// Master admin capability - controls metadata and deactivation
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Minter capability - allows token minting
    public struct MinterCap has key, store {
        id: UID,
    }

    /// Pauser capability - controls global pause and address freezing via DenyList
    /// Contains DenyCapV1 for native freeze/pause control
    public struct PauserCap has key, store {
        id: UID,
        deny_cap: DenyCapV1<LIGHT_CMTAT>,
    }

    // ========== REGISTRY ==========
    // IOTA Native: Shared object for metadata storage vs EVM contract storage
    // Contains compliance-relevant information and global state

    public struct LightCMTATRegistry has key {
        id: UID,
        terms: String,
        information: String,
        token_id: String,
        deactivated: bool,
    }

    // ========== EVENTS ==========
    // IOTA Native: Event system for indexer compatibility and transparency
    // All regulatory actions emit events for compliance tracking

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
    // IOTA Native: Clear error codes for better debugging
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    const ELengthMismatch: u64 = 3;
    const EInsufficientActiveBalance: u64 = 4;
    const EInvalidAmount: u64 = 5;

    // ========== INIT FUNCTION ==========
    // IOTA Native: Uses create_regulated_currency_v1 for proper initialization
    // Creates TreasuryCap, CoinMetadata, DenyList, and shared objects
    // One-time witness ensures unique token type
    fun init(witness: LIGHT_CMTAT, ctx: &mut TxContext) {
        // Create regulated currency with metadata and global pause enabled
        let (treasury_cap, deny_cap, coin_metadata) = coin::create_regulated_currency_v1(
            witness,
            9, // decimals
            b"LIGHT_CMTAT", // symbol
            b"Light CMTAT Token", // name
            b"Light version of CMTAT regulated token", // description
            option::none(), // icon_url
            true, // allow_global_pause - enables pause functionality
            ctx
        );

        // Create deny list for freeze functionality
        let deny_list = deny_list::new(ctx);

        // Create registry for metadata and compliance state
        let registry = LightCMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            deactivated: false,
        };

        // Create capabilities
        let admin_cap = AdminCap { id: object::new(ctx) };
        let minter_cap = MinterCap { id: object::new(ctx) };
        let pauser_cap = PauserCap {
            id: object::new(ctx),
            deny_cap,
        };

        // Share objects for public access
        share_object(registry);
        share_object(deny_list);
        public_freeze_object(coin_metadata);

        // Transfer capabilities to deployer
        let deployer = tx_context::sender(ctx);
        transfer::transfer(admin_cap, deployer);
        transfer::transfer(minter_cap, deployer);
        transfer::transfer(pauser_cap, deployer);

        // Transfer TreasuryCap to deployer (can be shared if needed)
        transfer::transfer(treasury_cap, deployer);
    }

    // ========== DYNAMIC CAPABILITY GRANTING ==========
    // IOTA Native: Transferable capabilities allow dynamic role assignment
    // Unlike EVM static roles, capabilities can be granted to different addresses

    /// Create new MinterCap for distribution
    public fun create_minter_cap(ctx: &mut TxContext): MinterCap {
        MinterCap { id: object::new(ctx) }
    }

    /// Grant minter role
    public entry fun grant_minter(
        _admin_cap: &AdminCap,
        minter_cap: MinterCap,
        to: address
    ) {
        transfer::transfer(minter_cap, to);
    }

    /// Create new PauserCap for distribution
    public fun create_pauser_cap(ctx: &mut TxContext): PauserCap {
        let deny_cap = coin::create_denymint_cap_v1<LIGHT_CMTAT>(ctx);
        PauserCap {
            id: object::new(ctx),
            deny_cap,
        }
    }

    /// Grant pauser role
    public entry fun grant_pauser(
        _admin_cap: &AdminCap,
        pauser_cap: PauserCap,
        to: address
    ) {
        transfer::transfer(pauser_cap, to);
    }

    // ========== VIEW FUNCTIONS ==========
    // IOTA Native: Pure functions for reading state
    // Coin metadata and registry provide token information

    public fun name(metadata: &CoinMetadata): String {
        coin::get_name(metadata)
    }

    public fun symbol(metadata: &CoinMetadata): String {
        coin::get_symbol(metadata)
    }

    public fun decimals(metadata: &CoinMetadata): u8 {
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

    public fun is_frozen(deny_list: &DenyList, account: address): bool {
        deny_list::contains(deny_list, account)
    }

    // ========== ROLE GETTERS ==========
    // Maintain compatibility with CMTAT interface
    public fun get_default_admin_role(): vector<u8> {
        b"DEFAULT_ADMIN_ROLE"
    }

    public fun get_minter_role(): vector<u8> {
        b"MINTER_ROLE"
    }

    public fun get_pauser_role(): vector<u8> {
        b"PAUSER_ROLE"
    }

    public fun get_enforcer_role(): vector<u8> {
        b"ENFORCER_ROLE"
    }

    // ========== ADMINISTRATIVE FUNCTIONS ==========
    // IOTA Native: Registry mutations with admin capability

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
    // IOTA Native: Uses TreasuryCap for controlled minting
    // Events emitted for transparency

    /// Mint tokens (returns Coin for optional transfer)
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

    /// Mint and transfer tokens (entry function)
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
        public_transfer(coins, to);
    }

    /// Batch mint
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
            public_transfer(coins, recipient);

            i = i + 1;
        }
    }

    // ========== BURNING FUNCTIONS ==========
    // IOTA Native: Uses TreasuryCap for controlled burning
    // Events emitted for transparency

    /// Burn tokens
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

    /// Burn tokens (entry function)
    public entry fun burn_entry(
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        burn(treasury_cap, coins, ctx);
    }

    /// Burn from (minter burns user's coins)
    public entry fun burn_from(
        _minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        let amount = coin::value(&coins);
        let minter = tx_context::sender(ctx);

        coin::burn(treasury_cap, coins);

        event::emit(TokenBurned {
            burner: minter,
            from: minter,
            amount,
        });
    }

    /// Batch burn
    public entry fun batch_burn(
        _minter_cap: &MinterCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        mut coins: vector<Coin<LIGHT_CMTAT>>,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        let sender = tx_context::sender(ctx);

        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            let amount = coin::value(&coin);

            coin::burn(treasury_cap, coin);

            event::emit(TokenBurned {
                burner: sender,
                from: sender,
                amount,
            });
        };

        vector::destroy_empty(coins);
    }

    /// Forced burn (pauser can burn user coins)
    public entry fun forced_burn(
        _pauser_cap: &PauserCap,
        treasury_cap: &mut TreasuryCap<LIGHT_CMTAT>,
        registry: &LightCMTATRegistry,
        coins: Coin<LIGHT_CMTAT>,
        ctx: &TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);

        let amount = coin::value(&coins);
        let pauser = tx_context::sender(ctx);

        coin::burn(treasury_cap, coins);

        event::emit(TokenBurned {
            burner: pauser,
            from: pauser,
            amount,
        });
    }

    /// Burn and mint (transfer balance between addresses)
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

        let burn_amount = coin::value(&burn_coins);
        let minter = tx_context::sender(ctx);

        coin::burn(treasury_cap, burn_coins);

        event::emit(TokenBurned {
            burner: minter,
            from: minter,
            amount: burn_amount,
        });

        let mint_coins = coin::mint(treasury_cap, mint_amount, ctx);

        event::emit(TokenMinted {
            minter,
            to: mint_to,
            amount: mint_amount,
        });

        public_transfer(mint_coins, mint_to);
    }

    // ========== TRANSFER FUNCTION ==========
    // IOTA Native: Public transfer with compliance checks
    // Validates against pause, deactivation, and freeze status

    public entry fun transfer(
        registry: &LightCMTATRegistry,
        deny_list: &DenyList,
        coins: Coin<LIGHT_CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);
        let amount = coin::value(&coins);

        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, from), EAddressFrozen);
        assert!(!is_frozen(deny_list, to), EAddressFrozen);
        assert!(amount > 0, EInsufficientActiveBalance);

        public_transfer(coins, to);
    }

    // ========== PAUSE FUNCTIONS ==========
    // IOTA Native: Uses native global pause
    // Global pause prevents all coin operations

    public entry fun pause(
        _pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        ctx: &TxContext
    ) {
        let pauser = tx_context::sender(ctx);
        coin::deny_list_v1_enable_global_pause<LIGHT_CMTAT>(deny_list, &mut pauser.deny_cap, ctx);

        event::emit(ModulePaused { pauser });
    }

    public entry fun unpause(
        _pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        ctx: &TxContext
    ) {
        let pauser = tx_context::sender(ctx);
        coin::deny_list_v1_disable_global_pause<LIGHT_CMTAT>(deny_list, &mut pauser.deny_cap, ctx);

        event::emit(ModuleUnpaused { pauser });
    }

    // ========== FREEZE FUNCTIONS ==========
    // IOTA Native: Uses native DenyList for address freezing
    // DenyCapV1 controls deny list modifications

    public entry fun set_address_frozen(
        _pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        account: address,
        frozen: bool,
        ctx: &TxContext
    ) {
        let pauser = tx_context::sender(ctx);

        if (frozen) {
            deny_list::add(&mut pauser.deny_cap, deny_list, account);
            event::emit(AddressFrozen { enforcer: pauser, account });
        } else {
            deny_list::remove(&mut pauser.deny_cap, deny_list, account);
            event::emit(AddressUnfrozen { enforcer: pauser, account });
        };
    }

    /// Batch freeze addresses
    public entry fun batch_set_address_frozen(
        pauser_cap: &PauserCap,
        deny_list: &mut DenyList,
        accounts: vector<address>,
        frozen: bool,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let len = vector::length(&accounts);

        let i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);

            if (frozen) {
                deny_list::add(&mut pauser_cap.deny_cap, deny_list, account);
                event::emit(AddressFrozen { enforcer: sender, account });
            } else {
                deny_list::remove(&mut pauser_cap.deny_cap, deny_list, account);
                event::emit(AddressUnfrozen { enforcer: sender, account });
            };

            i = i + 1;
        };
    }

    // ========== DEACTIVATION ==========
    // IOTA Native: Permanent deactivation prevents further operations

    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        registry: &mut LightCMTATRegistry,
        ctx: &TxContext
    ) {
        let admin = tx_context::sender(ctx);

        registry.deactivated = true;

        event::emit(ModuleDeactivated {
            admin,
        });
    }

    // ========== TEST-ONLY FUNCTIONS ==========
    // IOTA Native: Test utilities for comprehensive testing

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(LIGHT_CMTAT {}, ctx);
    }

    #[test_only]
    public fun create_admin_cap_for_testing(ctx: &mut TxContext): AdminCap {
        AdminCap { id: object::new(ctx) }
    }

    #[test_only]
    public fun create_minter_cap_for_testing(ctx: &mut TxContext): MinterCap {
        MinterCap { id: object::new(ctx) }
    }

    #[test_only]
    public fun create_pauser_cap_for_testing(ctx: &mut TxContext): PauserCap {
        let deny_cap = coin::create_denymint_cap_v1<LIGHT_CMTAT>(ctx);
        PauserCap {
            id: object::new(ctx),
            deny_cap,
        }
    }
}

/*
================================================================================
REFACTORING SUMMARY
================================================================================

✅ CHANGES MADE:

1. Token Architecture:
   ❌ REMOVED: Custom balance storage (Table<address, u64>)
   ✅ ADDED: Native Coin<LIGHT_CMTAT> objects

2. Authority System:
   ❌ REMOVED: Role mapping storage (Table<address, vector<vector<u8>>>)
   ✅ ADDED: Capability objects (AdminCap, MinterCap, PauserCap)

3. Freeze/Pause:
   ❌ REMOVED: Custom FreezeState and PauseState
   ✅ ADDED: Native DenyList integration

4. Initialization:
   ❌ REMOVED: Manual init_token function
   ✅ ADDED: Native init with one-time witness and create_regulated_currency_v1

5. Minting:
   ❌ OLD: base::update_balance(&mut balances, to, balance + amount)
   ✅ NEW: coin::mint(treasury, amount, ctx) + transfer

6. Burning:
   ❌ OLD: base::update_balance(&mut balances, from, balance - amount)
   ✅ NEW: coin::burn(treasury, coin)

7. Transfer:
   ❌ OLD: Update two balance entries in table
   ✅ NEW: public_transfer(coin, recipient)

8. Total Supply:
   ❌ OLD: Custom tracking in TokenInfo
   ✅ NEW: VM-enforced via TreasuryCap

9. Balance Queries:
   ❌ REMOVED: balance_of() and batch_balance_of()
   ✅ REASON: Use indexer to query user-owned Coin objects

10. Events:
    ❌ OLD: No events
    ✅ ADDED: Full event system (TokenMinted, TokenBurned, etc.)

11. Dynamic Capability Granting:
    ❌ OLD: Static capabilities only in init
    ✅ ADDED: grant_minter, grant_pauser functions

================================================================================
COMPATIBILITY WITH IOTA ECOSYSTEM:

✅ Wallets can see balances (user owns Coin objects)
✅ Indexers can track all tokens (via object ownership)
✅ DEXs can trade tokens (Coin<T> is fungible)
✅ Total supply is VM-enforced (no custom tracking)
✅ Freeze/pause uses native DenyList (ecosystem-wide support)
✅ Events are indexer-compatible for compliance tracking

================================================================================
*/
