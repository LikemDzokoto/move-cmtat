/// Debt CMTAT - CMTAT for Debt Securities
/// Specialized for corporate bonds and debt instruments
/// Implements 10 roles including DEBT_ROLE
module move_cmtat::debt_cmtat {
    use std::string::String;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::clock::{Self, Clock};
    
    use move_cmtat::base;
    use move_cmtat::pause;
    use move_cmtat::freeze;
    use move_cmtat::debt;
    use move_cmtat::rule_engine;
    use move_cmtat::snapshot_engine;
    use move_cmtat::icmtat;

    /// Errors
    const ETransferRestricted: u64 = 3004;

    /// Debt CMTAT Token shared object
    public struct DebtCMTAT has key {
        id: UID,
        token_info: base::TokenInfo,
        treasury_cap: TreasuryCap<base::CMTAT>,
        snapshot_engine: snapshot_engine::SnapshotEngine,
        document_uri: String,
    }

    /// Shared compliance state object (includes debt state)
    public struct ComplianceState has key {
        id: UID,
        pause_state: pause::PauseState,
        freeze_state: freeze::FreezeState,
        debt_state: debt::DebtState,
    }

    /// Capability structs for access control
    public struct AdminCap has key, store { id: UID }
    public struct MintCap has key, store { id: UID }
    public struct BurnCap has key, store { id: UID }
    public struct FreezeCap has key, store { id: UID }
    public struct PauseCap has key, store { id: UID }
    public struct SnapshotCap has key, store { id: UID }
    public struct DebtCap has key, store { id: UID }

    /// Initialize Debt CMTAT with native IOTA token architecture
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
        let token = DebtCMTAT {
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
            debt_state: debt::init_debt_state(ctx),
        };

        // Create capability objects
        let admin = tx_context::sender(ctx);
        let admin_cap = AdminCap { id: object::new(ctx) };
        let mint_cap = MintCap { id: object::new(ctx) };
        let burn_cap = BurnCap { id: object::new(ctx) };
        let freeze_cap = FreezeCap { id: object::new(ctx) };
        let pause_cap = PauseCap { id: object::new(ctx) };
        let snapshot_cap = SnapshotCap { id: object::new(ctx) };
        let debt_cap = DebtCap { id: object::new(ctx) };

        // Share objects
        transfer::share_object(token);
        transfer::share_object(compliance_state);

        // Transfer capabilities to admin
        transfer::transfer(admin_cap, admin);
        transfer::transfer(mint_cap, admin);
        transfer::transfer(burn_cap, admin);
        transfer::transfer(freeze_cap, admin);
        transfer::transfer(pause_cap, admin);
        transfer::transfer(snapshot_cap, admin);
        transfer::transfer(debt_cap, admin);

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
         base::total_supply(&token.treasury_cap)
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

     public fun debt(compliance_state: &ComplianceState): String {
         debt::get_debt(&compliance_state.debt_state)
     }

     public fun credit_events(compliance_state: &ComplianceState): String {
         debt::get_credit_events(&compliance_state.debt_state)
     }

     public fun debt_engine(compliance_state: &ComplianceState): address {
         debt::get_debt_engine(&compliance_state.debt_state)
     }

     public fun is_default_flagged(compliance_state: &ComplianceState): bool {
         debt::is_default_flagged(&compliance_state.debt_state)
     }

    public fun document_uri(token: &DebtCMTAT): String {
        token.document_uri
    }

    // ============ Administrative Functions ============

     public entry fun set_terms(
         _admin_cap: &AdminCap,
         token: &mut DebtCMTAT,
         new_terms: String
     ) {
         base::set_terms(&mut token.token_info, new_terms);
     }

     public entry fun set_information(
         _admin_cap: &AdminCap,
         token: &mut DebtCMTAT,
         new_info: String
     ) {
         base::set_information(&mut token.token_info, new_info);
     }

     public entry fun set_token_id(
         _admin_cap: &AdminCap,
         token: &mut DebtCMTAT,
         new_id: String
     ) {
         base::set_token_id(&mut token.token_info, new_id);
     }

     public entry fun set_document_uri(
         _admin_cap: &AdminCap,
         token: &mut DebtCMTAT,
         uri: String
     ) {
         token.document_uri = uri;
     }

    // ============ Debt-Specific Functions ============

     public entry fun set_debt(
         _debt_cap: &DebtCap,
         compliance_state: &mut ComplianceState,
         debt_info: String
     ) {
         debt::set_debt(&mut compliance_state.debt_state, debt_info);
     }

     public entry fun set_credit_events(
         _debt_cap: &DebtCap,
         compliance_state: &mut ComplianceState,
         events: String
     ) {
         debt::set_credit_events(&mut compliance_state.debt_state, events);
     }

     public entry fun set_debt_engine(
         _debt_cap: &DebtCap,
         compliance_state: &mut ComplianceState,
         engine: address
     ) {
         debt::set_debt_engine(&mut compliance_state.debt_state, engine);
     }

     public entry fun flag_default(
         _debt_cap: &DebtCap,
         compliance_state: &mut ComplianceState
     ) {
         debt::flag_default(&mut compliance_state.debt_state);
     }

    // ============ Minting Functions ============

    public entry fun mint(
        _mint_cap: &MintCap,
        token: &mut DebtCMTAT,
        compliance_state: &ComplianceState,
        to: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        pause::require_not_paused(&compliance_state.pause_state);
        freeze::require_not_frozen(&compliance_state.freeze_state, to);
        debt::require_not_in_default(&compliance_state.debt_state);

        let coins = base::mint(&mut token.treasury_cap, amount, ctx);
        base::transfer_coin(coins, to);
     }

     // ============ Burning Functions ============

     /// Burn coins provided by the user
     public entry fun burn(
         token: &mut DebtCMTAT,
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

     public entry fun freeze_partial_tokens(
         _freeze_cap: &FreezeCap,
         compliance_state: &mut ComplianceState,
         account: address,
         amount: u64
     ) {
         freeze::freeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
     }

     public entry fun unfreeze_partial_tokens(
         _freeze_cap: &FreezeCap,
         compliance_state: &mut ComplianceState,
         account: address,
         amount: u64
     ) {
         freeze::unfreeze_partial_tokens(&mut compliance_state.freeze_state, account, amount);
     }

    // ============ Snapshot Functions ============

     public entry fun schedule_snapshot(
         _snapshot_cap: &SnapshotCap,
         token: &mut DebtCMTAT,
         clock: &Clock,
         ctx: &mut TxContext
     ) {
         let timestamp = clock::timestamp_ms(clock);
         let total_supply = base::total_supply(&token.treasury_cap);

         snapshot_engine::create_snapshot(&mut token.snapshot_engine, total_supply, timestamp, ctx);
     }

     // ============ Transfer Functions ============

     /// Transfer function with CMTAT compliance validation
     /// Users call this to transfer their Coin<CMTAT> with regulatory checks
      public entry fun transfer(
          _compliance_state: &ComplianceState,
          coins: Coin<base::CMTAT>,
          to: address,
          ctx: &TxContext
      ) {
          let _from = tx_context::sender(ctx);
          let _amount = base::coin_value(&coins);

          // Validate transfer using rule engine (without allowlist)
          let restriction_code = rule_engine::validate_transfer(
              &_compliance_state.pause_state,
              &_compliance_state.freeze_state,
              _from,
              to,
              _amount,
              _amount  // from_balance is the coin value being transferred
          );

         assert!(restriction_code == icmtat::restriction_code_valid(), ETransferRestricted);

         // Transfer the coins
         base::transfer_coin(coins, to);
     }
}
