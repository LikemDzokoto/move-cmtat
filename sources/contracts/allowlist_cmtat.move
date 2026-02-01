/// Allowlist CMTAT - Native Coin<T> with Allowlist Functionality
/// All Light features plus allowlist control and partial token freezing
/// Uses native IOTA DenyList + custom allowlist state
module move_cmtat::allowlist_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::DenyList;
    use iota::clock::{Self, Clock};
    use iota::event;
    
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::allowlist;
    use move_cmtat::rule_engine;
    use move_cmtat::snapshot_engine;
    use move_cmtat::icmtat;

    // ========== ONE-TIME WITNESS ==========
    public struct ALLOWLIST_CMTAT has drop {}

    // ========== CMTAT REGISTRY ==========
    public struct CMTATRegistry has key {
        id: UID,
        terms: String,
        information: String,
        token_id: String,
        document_uri: String,
        deactivated: bool,
    }

    public struct AllowlistCMTATState has key {
        id: UID,
        snapshot_engine: snapshot_engine::SnapshotEngine,
    }

    public struct ComplianceState has key {
        id: UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        allowlist_state: allowlist::AllowlistState,
    }

    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct FreezeCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }
    public struct AllowlistCap has key, store { id: UID }
    public struct SnapshotCap has key, store { id: UID }
    public struct EnforcerCap has key, store { id: UID }

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

    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;
    const ETransferRestricted: u64 = 3;

    fun init(witness: ALLOWLIST_CMTAT, ctx: &mut TxContext) {
        let (treasury_cap, deny_cap, coin_metadata) = coin::create_regulated_currency_v1(
            witness,
            9,
            b"ALCMTAT",
            b"Allowlist CMTAT Token",
            b"CMTAT with allowlist functionality",
            option::none(),
            true,
            ctx
        );

        let registry = CMTATRegistry {
            id: object::new(ctx),
            terms: string::utf8(b""),
            information: string::utf8(b""),
            token_id: string::utf8(b""),
            document_uri: string::utf8(b""),
            deactivated: false,
        };

        let state = AllowlistCMTATState {
            id: object::new(ctx),
            snapshot_engine: snapshot_engine::init_snapshot_engine(ctx),
        };

        let compliance_state = ComplianceState {
            id: object::new(ctx),
            pause_state: pause::init_pause_state(ctx),
            freeze_state: freeze::init_freeze_state(ctx),
            allowlist_state: allowlist::init_allowlist_state(ctx),
        };

        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };
        let allowlist_cap = AllowlistCap { id: object::new(ctx) };
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };

        transfer::public_transfer(treasury_cap, deployer);
        transfer::public_transfer(deny_cap, deployer);
        transfer::public_freeze_object(coin_metadata);
        
        transfer::share_object(registry);
        transfer::share_object(state);
        transfer::share_object(compliance_state);

        transfer::transfer(admin_cap, deployer);
        transfer::transfer(mint_cap, deployer);
        transfer::transfer(burn_cap, deployer);
        transfer::transfer(freeze_cap, deployer);
        transfer::transfer(pause_cap, deployer);
        transfer::transfer(allowlist_cap, deployer);
        transfer::transfer(snapshot_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
    }

    public fun name(metadata: &CoinMetadata<ALLOWLIST_CMTAT>): String {
        coin::get_name(metadata)
    }

    public fun symbol(metadata: &CoinMetadata<ALLOWLIST_CMTAT>): String {
        string::from_ascii(coin::get_symbol(metadata))
    }

    public fun decimals(metadata: &CoinMetadata<ALLOWLIST_CMTAT>): u8 {
        coin::get_decimals(metadata)
    }

    public fun total_supply(treasury_cap: &TreasuryCap<ALLOWLIST_CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    public fun terms(registry: &CMTATRegistry): String { registry.terms }
    public fun information(registry: &CMTATRegistry): String { registry.information }
    public fun token_id(registry: &CMTATRegistry): String { registry.token_id }
    public fun document_uri(registry: &CMTATRegistry): String { registry.document_uri }
    public fun deactivated(registry: &CMTATRegistry): bool { registry.deactivated }

    public fun paused(compliance_state: &ComplianceState): bool {
        pause::is_paused(&compliance_state.pause_state)
    }

    public fun is_frozen(compliance_state: &ComplianceState, account: address): bool {
        freeze::is_frozen(&compliance_state.freeze_state, account)
    }

    public fun is_allowlisted(compliance_state: &ComplianceState, account: address): bool {
        allowlist::is_allowlisted(&compliance_state.allowlist_state, account)
    }

    public fun allowlist_enabled(compliance_state: &ComplianceState): bool {
        allowlist::is_enabled(&compliance_state.allowlist_state)
    }

    public fun is_paused_native(deny_list: &DenyList, ctx: &TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<ALLOWLIST_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen_native(deny_list: &DenyList, account: address, ctx: &TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<ALLOWLIST_CMTAT>(deny_list, account, ctx)
    }

    public entry fun set_terms(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_terms: String
    ) {
        registry.terms = new_terms;
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_info: String
    ) {
        registry.information = new_info;
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_id: String
    ) {
        registry.token_id = new_id;
    }

    public entry fun set_document_uri(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        uri: String
    ) {
        registry.document_uri = uri;
    }

    public fun mint(
        _mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<ALLOWLIST_CMTAT> {
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);
        
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);
        allowlist::require_allowlisted(&compliance_state.allowlist_state, to);

        let coins = coin::mint(treasury_cap, amount, ctx);

        event::emit(TokenMinted {
            minter: tx_context::sender(ctx),
            to,
            amount,
        });

        coins
    }

    public entry fun mint_and_transfer(
        mint_cap: &MintCap,
        treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>,
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coins = mint(mint_cap, treasury_cap, registry, compliance_state, deny_list, to, amount, ctx);
        transfer::public_transfer(coins, to);
    }

    public fun burn(treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>, coins: Coin<ALLOWLIST_CMTAT>, ctx: &TxContext) {
        let amount = coin::value(&coins);
        let burner = tx_context::sender(ctx);
        coin::burn(treasury_cap, coins);
        event::emit(TokenBurned { burner, from: burner, amount });
    }

    public entry fun burn_entry(treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>, coins: Coin<ALLOWLIST_CMTAT>, compliance_state: &ComplianceState, ctx: &TxContext) {
        pause::require_not_paused(&compliance_state.pause_state);
        burn(treasury_cap, coins, ctx);
    }

    public entry fun pause(_pause_cap: &PauseCap, compliance_state: &mut ComplianceState) {
        pause::pause(&mut compliance_state.pause_state);
    }

    public entry fun unpause(_pause_cap: &PauseCap, compliance_state: &mut ComplianceState) {
        pause::unpause(&mut compliance_state.pause_state);
    }

    public entry fun pause_native(_pause_cap: &PauseCap, deny_list: &mut DenyList, deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>, registry: &CMTATRegistry, ctx: &mut TxContext) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);
    }

    public entry fun unpause_native(_pause_cap: &PauseCap, deny_list: &mut DenyList, deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>, registry: &CMTATRegistry, ctx: &mut TxContext) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_disable_global_pause(deny_list, deny_cap, ctx);
    }

    public entry fun deactivate_contract(_admin_cap: &AdminCap, registry: &mut CMTATRegistry, compliance_state: &mut ComplianceState) {
        registry.deactivated = true;
        pause::deactivate(&mut compliance_state.pause_state);
    }

    public entry fun set_address_frozen(_freeze_cap: &FreezeCap, compliance_state: &mut ComplianceState, account: address, frozen: bool) {
        freeze::set_address_frozen(&mut compliance_state.freeze_state, account, frozen);
    }

    public entry fun set_address_frozen_native(_enforcer_cap: &EnforcerCap, deny_list: &mut DenyList, deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>, account: address, frozen: bool, ctx: &mut TxContext) {
        let enforcer = tx_context::sender(ctx);
        if (frozen) {
            coin::deny_list_v1_add(deny_list, deny_cap, account, ctx);
            event::emit(AddressFrozen { enforcer, account });
        } else {
            coin::deny_list_v1_remove(deny_list, deny_cap, account, ctx);
            event::emit(AddressUnfrozen { enforcer, account });
        }
    }

    public entry fun freeze_partial_tokens(_freeze_cap: &FreezeCap, compliance_state: &mut ComplianceState, account: address, amount: u64) {
        freeze::freeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
    }

    public entry fun unfreeze_partial_tokens(_freeze_cap: &FreezeCap, compliance_state: &mut ComplianceState, account: address, amount: u64) {
        freeze::unfreeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
    }

    public entry fun enable_allowlist(_allowlist_cap: &AllowlistCap, compliance_state: &mut ComplianceState, enabled: bool) {
        allowlist::set_enabled(&mut compliance_state.allowlist_state, enabled);
    }

    public entry fun set_address_allowlist(_allowlist_cap: &AllowlistCap, compliance_state: &mut ComplianceState, account: address, status: bool) {
        allowlist::set_address_allowlist(&mut compliance_state.allowlist_state, account, status);
    }

    public entry fun schedule_snapshot(_snapshot_cap: &SnapshotCap, state: &mut AllowlistCMTATState, treasury_cap: &TreasuryCap<ALLOWLIST_CMTAT>, clock: &Clock, ctx: &mut TxContext) {
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = coin::total_supply(treasury_cap);
        snapshot_engine::create_snapshot(&mut state.snapshot_engine, total_supply, timestamp, ctx);
    }

    public entry fun transfer(registry: &CMTATRegistry, compliance_state: &ComplianceState, deny_list: &DenyList, coins: Coin<ALLOWLIST_CMTAT>, to: address, ctx: &TxContext) {
        let from = tx_context::sender(ctx);
        let amount = coin::value(&coins);
        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused_native(deny_list, ctx), EModulePaused);
        assert!(!is_frozen_native(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen_native(deny_list, to, ctx), EAddressFrozen);
        let restriction_code = rule_engine::validate_transfer_with_allowlist(&compliance_state.pause_state, &compliance_state.freeze_state, &compliance_state.allowlist_state, from, to, amount, amount);
        assert!(restriction_code == icmtat::restriction_code_valid(), ETransferRestricted);
        transfer::public_transfer(coins, to);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ALLOWLIST_CMTAT {}, ctx);
    }
}
