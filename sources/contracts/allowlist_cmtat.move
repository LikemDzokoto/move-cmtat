/// Allowlist CMTAT - Native Coin<T> with Allowlist Functionality
/// All Light features plus allowlist control
/// Uses native IOTA DenyList + custom allowlist state
module move_cmtat::allowlist_cmtat {
    use std::string::{Self, String};
    use iota::coin::{Self, Coin, TreasuryCap, DenyCapV1, CoinMetadata};
    use iota::deny_list::DenyList;
    use iota::clock::{Self, Clock};
    use iota::event;

    use move_cmtat::allowlist;
    use move_cmtat::snapshot_engine;

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

    // ========== COMPLIANCE STATE (allowlist only) ==========
    public struct ComplianceState has key {
        id: UID,
        allowlist_state: allowlist::AllowlistState,
    }

    // ========== CAPABILITIES ==========
    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }
    public struct AllowlistCap has key, store { id: UID }
    public struct SnapshotCap has key, store { id: UID }
    public struct EnforcerCap has key, store { id: UID }

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

    public struct TermsUpdated has copy, drop {
        admin: address,
        new_terms: String,
    }

    public struct InformationUpdated has copy, drop {
        admin: address,
        new_information: String,
    }

    public struct TokenIdUpdated has copy, drop {
        admin: address,
        new_token_id: String,
    }

    public struct DocumentUriUpdated has copy, drop {
        admin: address,
        new_document_uri: String,
    }

    public struct AllowlistEnabled has copy, drop {
        allowlist_manager: address,
        enabled: bool,
    }

    public struct AddressAllowlistedUpdated has copy, drop {
        allowlist_manager: address,
        account: address,
        status: bool,
    }

    // ========== ERRORS ==========
    const EModuleDeactivated: u64 = 0;
    const EAddressFrozen: u64 = 1;
    const EModulePaused: u64 = 2;

    // ========== INIT FUNCTION ==========
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

        // Create compliance state with allowlist state only
        let compliance_state = ComplianceState {
            id: object::new(ctx),
            allowlist_state: allowlist::init_allowlist_state(ctx),
        };

        let deployer = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
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
        transfer::transfer(pause_cap, deployer);
        transfer::transfer(allowlist_cap, deployer);
        transfer::transfer(snapshot_cap, deployer);
        transfer::transfer(enforcer_cap, deployer);
    }

    // ========== VIEW FUNCTIONS (Native CoinMetadata) ==========
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

    // ========== REGISTRY VIEWS ==========
    public fun terms(registry: &CMTATRegistry): String { registry.terms }
    public fun information(registry: &CMTATRegistry): String { registry.information }
    public fun token_id(registry: &CMTATRegistry): String { registry.token_id }
    public fun document_uri(registry: &CMTATRegistry): String { registry.document_uri }
    public fun deactivated(registry: &CMTATRegistry): bool { registry.deactivated }

    // ========== COMPLIANCE VIEWS (Native DenyList) ==========
    public fun is_paused(deny_list: &DenyList, ctx: &TxContext): bool {
        coin::deny_list_v1_is_global_pause_enabled_current_epoch<ALLOWLIST_CMTAT>(deny_list, ctx)
    }

    public fun is_frozen(deny_list: &DenyList, account: address, ctx: &TxContext): bool {
        coin::deny_list_v1_contains_current_epoch<ALLOWLIST_CMTAT>(deny_list, account, ctx)
    }

    // ========== ALLOWLIST VIEWS ==========
    public fun is_allowlisted(compliance_state: &ComplianceState, account: address): bool {
        allowlist::is_allowlisted(&compliance_state.allowlist_state, account)
    }

    public fun allowlist_enabled(compliance_state: &ComplianceState): bool {
        allowlist::is_enabled(&compliance_state.allowlist_state)
    }

    // ========== CAPABILITY GRANTING ==========
    // Note: Grant functions transfer TreasuryCap/DenyCap to enable EVM-like behavior
    public entry fun grant_minter(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<ALLOWLIST_CMTAT>,
        to: address,
        ctx: &mut TxContext
    ) {
        let mint_cap = MintCap { id: object::new(ctx) };
        transfer::transfer(mint_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_burner(
        _admin_cap: &AdminCap,
        treasury_cap: TreasuryCap<ALLOWLIST_CMTAT>,
        to: address,
        ctx: &mut TxContext
    ) {
        let burn_cap = BurnCap { id: object::new(ctx) };
        transfer::transfer(burn_cap, to);
        transfer::public_transfer(treasury_cap, to);
    }

    public entry fun grant_pauser(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<ALLOWLIST_CMTAT>,
        to: address,
        ctx: &mut TxContext
    ) {
        let pause_cap = PauseCap { id: object::new(ctx) };
        transfer::transfer(pause_cap, to);
        transfer::public_transfer(deny_cap, to);
    }

    public entry fun grant_enforcer(
        _admin_cap: &AdminCap,
        deny_cap: DenyCapV1<ALLOWLIST_CMTAT>,
        to: address,
        ctx: &mut TxContext
    ) {
        let enforcer_cap = EnforcerCap { id: object::new(ctx) };
        transfer::transfer(enforcer_cap, to);
        transfer::public_transfer(deny_cap, to);
    }

    public entry fun grant_snapshooter(
        _admin_cap: &AdminCap,
        to: address,
        ctx: &mut TxContext
    ) {
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        transfer::transfer(snapshot_cap, to);
    }

    public entry fun grant_allowlist_manager(
        _admin_cap: &AdminCap,
        allowlist_cap: AllowlistCap,
        to: address,
        ctx: &mut TxContext
    ) {
        let new_allowlist_cap = AllowlistCap { id: object::new(ctx) };
        transfer::transfer(new_allowlist_cap, to);
        transfer::public_transfer(allowlist_cap, to);
    }

    // ========== CAPABILITY REVOKING ==========
    public entry fun revoke_minter(
        _admin_cap: &AdminCap,
        minter_cap: MintCap,
    ) {
        let MintCap { id } = minter_cap;
        object::delete(id);
    }

    public entry fun revoke_burner(
        _admin_cap: &AdminCap,
        burn_cap: BurnCap,
    ) {
        let BurnCap { id } = burn_cap;
        object::delete(id);
    }

    public entry fun revoke_pauser(
        _admin_cap: &AdminCap,
        pause_cap: PauseCap,
    ) {
        let PauseCap { id } = pause_cap;
        object::delete(id);
    }

    public entry fun revoke_enforcer(
        _admin_cap: &AdminCap,
        enforcer_cap: EnforcerCap,
    ) {
        let EnforcerCap { id } = enforcer_cap;
        object::delete(id);
    }

    public entry fun revoke_snapshooter(
        _admin_cap: &AdminCap,
        snapshot_cap: SnapshotCap,
    ) {
        let SnapshotCap { id } = snapshot_cap;
        object::delete(id);
    }

    public entry fun revoke_allowlist_manager(
        _admin_cap: &AdminCap,
        allowlist_cap: AllowlistCap,
    ) {
        let AllowlistCap { id } = allowlist_cap;
        object::delete(id);
    }

    // ========== ADMINISTRATIVE FUNCTIONS ==========
    public entry fun set_terms(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_terms: String,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.terms = new_terms;

        event::emit(TermsUpdated {
            admin,
            new_terms,
        });
    }

    public entry fun set_information(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_info: String,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.information = new_info;

        event::emit(InformationUpdated {
            admin,
            new_information: new_info,
        });
    }

    public entry fun set_token_id(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        new_id: String,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.token_id = new_id;

        event::emit(TokenIdUpdated {
            admin,
            new_token_id: new_id,
        });
    }

    public entry fun set_document_uri(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        uri: String,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        registry.document_uri = uri;

        event::emit(DocumentUriUpdated {
            admin,
            new_document_uri: uri,
        });
    }

    // ========== MINTING FUNCTIONS (Native Coin<T>) ==========
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
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);
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

    // ========== BURNING FUNCTIONS (Native Coin<T>) ==========
    public fun burn(
        treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>,
        coins: Coin<ALLOWLIST_CMTAT>,
        ctx: &TxContext
    ) {
        let amount = coin::value(&coins);
        let burner = tx_context::sender(ctx);
        coin::burn(treasury_cap, coins);
        event::emit(TokenBurned { burner, from: burner, amount });
    }

    public entry fun burn_entry(
        treasury_cap: &mut TreasuryCap<ALLOWLIST_CMTAT>,
        coins: Coin<ALLOWLIST_CMTAT>,
        deny_list: &DenyList,
        ctx: &TxContext
    ) {
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        burn(treasury_cap, coins, ctx);
    }

    // ========== PAUSE FUNCTIONS (Native DenyList) ==========
    public entry fun pause(
        _pause_cap: &PauseCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModulePaused {
            pauser: tx_context::sender(ctx),
        });
    }

    public entry fun unpause(
        _pause_cap: &PauseCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>,
        registry: &CMTATRegistry,
        ctx: &mut TxContext
    ) {
        assert!(!registry.deactivated, EModuleDeactivated);
        coin::deny_list_v1_disable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleUnpaused {
            pauser: tx_context::sender(ctx),
        });
    }

    public entry fun deactivate_contract(
        _admin_cap: &AdminCap,
        registry: &mut CMTATRegistry,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>,
        ctx: &mut TxContext
    ) {
        registry.deactivated = true;
        coin::deny_list_v1_enable_global_pause(deny_list, deny_cap, ctx);

        event::emit(ModuleDeactivated {
            admin: tx_context::sender(ctx),
        });
    }

    // ========== FREEZE FUNCTIONS (Native DenyList) ==========
    public entry fun set_address_frozen(
        _enforcer_cap: &EnforcerCap,
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>,
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
        deny_cap: &mut DenyCapV1<ALLOWLIST_CMTAT>,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &mut TxContext
    ) {
        let len = vector::length(&accounts);
        assert!(len == vector::length(&statuses), 0);

        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);

            set_address_frozen(enforcer_cap, deny_list, deny_cap, account, status, ctx);

            i = i + 1;
        }
    }

    // ========== ALLOWLIST FUNCTIONS ==========
    public entry fun enable_allowlist(
        _allowlist_cap: &AllowlistCap,
        compliance_state: &mut ComplianceState,
        enabled: bool,
        ctx: &mut TxContext
    ) {
        allowlist::set_enabled(&mut compliance_state.allowlist_state, enabled);

        event::emit(AllowlistEnabled {
            allowlist_manager: tx_context::sender(ctx),
            enabled,
        });
    }

    public entry fun set_address_allowlist(
        _allowlist_cap: &AllowlistCap,
        compliance_state: &mut ComplianceState,
        account: address,
        status: bool,
        ctx: &mut TxContext
    ) {
        allowlist::set_address_allowlist(&mut compliance_state.allowlist_state, account, status);

        event::emit(AddressAllowlistedUpdated {
            allowlist_manager: tx_context::sender(ctx),
            account,
            status,
        });
    }

    public entry fun batch_set_address_allowlist(
        _allowlist_cap: &AllowlistCap,
        compliance_state: &mut ComplianceState,
        accounts: vector<address>,
        statuses: vector<bool>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        allowlist::batch_set_address_allowlist(&mut compliance_state.allowlist_state, accounts, statuses);

        let len = vector::length(&accounts);
        let mut i = 0;
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            let status = *vector::borrow(&statuses, i);
            event::emit(AddressAllowlistedUpdated {
                allowlist_manager: sender,
                account,
                status,
            });
            i = i + 1;
        };
    }

    // ========== SNAPSHOT FUNCTIONS ==========
    public entry fun schedule_snapshot(
        _snapshot_cap: &SnapshotCap,
        state: &mut AllowlistCMTATState,
        treasury_cap: &TreasuryCap<ALLOWLIST_CMTAT>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let timestamp = clock::timestamp_ms(clock);
        let total_supply = coin::total_supply(treasury_cap);
        snapshot_engine::create_snapshot(&mut state.snapshot_engine, total_supply, timestamp, ctx);
    }

    // ========== TRANSFER FUNCTIONS WITH VALIDATION ==========
    public entry fun transfer(
        registry: &CMTATRegistry,
        compliance_state: &ComplianceState,
        deny_list: &DenyList,
        coins: Coin<ALLOWLIST_CMTAT>,
        to: address,
        ctx: &TxContext
    ) {
        let from = tx_context::sender(ctx);

        assert!(!registry.deactivated, EModuleDeactivated);
        assert!(!is_paused(deny_list, ctx), EModulePaused);
        assert!(!is_frozen(deny_list, from, ctx), EAddressFrozen);
        assert!(!is_frozen(deny_list, to, ctx), EAddressFrozen);

        // Check allowlist for receiver
        allowlist::require_allowlisted(&compliance_state.allowlist_state, to);

        transfer::public_transfer(coins, to);
    }

    // ========== TEST-ONLY ==========
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ALLOWLIST_CMTAT {}, ctx);
    }
}
