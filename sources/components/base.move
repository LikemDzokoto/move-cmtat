/// Base Component - Core IOTA Native Token Functionality
/// 
/// ⚠️ ⚠️ ⚠️ THIS MODULE IS DEPRECATED ⚠️ ⚠️ ⚠️
/// 
/// DO NOT USE THIS MODULE IN NEW CODE
/// 
/// All CMTAT contracts now use native IOTA Coin<T> directly via:
/// - coin::create_regulated_currency_v1() for TreasuryCap + DenyCapV1 + CoinMetadata
/// - Immutable CoinMetadata (frozen after creation)
/// - Direct coin::mint(), coin::burn(), coin::value() calls
/// - Native DenyList integration for freeze/pause
/// - Unique phantom types per contract (STANDARD_CMTAT, ALLOWLIST_CMTAT, DEBT_CMTAT)
///
/// This module is kept ONLY for:
/// 1. Historical reference
/// 2. Understanding the migration from custom to native implementation
/// 3. Backwards compatibility during transition period
///
/// Migration Guide:
/// OLD: use move_cmtat::base; let coins = base::mint(&mut treasury_cap, amount, ctx);
/// NEW: use iota::coin; let coins = coin::mint(treasury_cap, amount, ctx);
///
/// OLD: base::TokenInfo struct
/// NEW: CMTATRegistry struct (CMTAT-specific) + CoinMetadata<T> (native)
///
/// OLD: TreasuryCap<base::CMTAT> (shared across all contracts)
/// NEW: TreasuryCap<STANDARD_CMTAT> | TreasuryCap<ALLOWLIST_CMTAT> | TreasuryCap<DEBT_CMTAT>
///
/// See refactored contracts for implementation examples.
/// 
module move_cmtat::base {
    use std::string::String;
    use iota::object::{Self, UID};  
    use iota::tx_context::TxContext;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::transfer;

    /// Phantom type for CMTAT token
    /// ⚠️ DEPRECATED: Each contract now has its own unique phantom type
    public struct CMTAT has drop {}

    /// Token metadata
    /// ⚠️ DEPRECATED: Use CMTATRegistry + native CoinMetadata<T> instead
    public struct TokenInfo has key, store {
        id: UID,
        name: String,
        symbol: String,
        decimals: u8,
        terms: String,
        information: String,
        token_id: String,
    }

    /// Initialize token info
    /// ⚠️ DEPRECATED: Use CMTATRegistry constructor instead
    public fun init_token_info(
        name: String,
        symbol: String,
        decimals: u8,
        ctx: &mut TxContext
    ): TokenInfo {
        TokenInfo {
            id: object::new(ctx),
            name,
            symbol,
            decimals,
            terms: std::string::utf8(b""),
            information: std::string::utf8(b""),
            token_id: std::string::utf8(b""),
        }
    }

    /// Information getters
    public fun name(info: &TokenInfo): String { info.name }
    public fun symbol(info: &TokenInfo): String { info.symbol }
    public fun decimals(info: &TokenInfo): u8 { info.decimals }
    public fun terms(info: &TokenInfo): String { info.terms }
    public fun information(info: &TokenInfo): String { info.information }
    public fun token_id(info: &TokenInfo): String { info.token_id }

    /// Information setters
    public fun set_terms(info: &mut TokenInfo, new_terms: String) {
        info.terms = new_terms;
    }

    public fun set_information(info: &mut TokenInfo, new_info: String) {
        info.information = new_info;
    }

    public fun set_token_id(info: &mut TokenInfo, new_id: String) {
        info.token_id = new_id;
    }

    /// Get total supply from TreasuryCap
    /// ⚠️ DEPRECATED: Use coin::total_supply(treasury_cap) directly
    public fun total_supply(treasury_cap: &TreasuryCap<CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    /// Create treasury cap - STUB FUNCTION (DO NOT USE)
    /// ⚠️ DEPRECATED: Use coin::create_regulated_currency_v1() instead
    public fun create_treasury_cap(_ctx: &mut TxContext): TreasuryCap<CMTAT> {
        abort 999 // This function should never be called
    }

    /// Destroy a zero-value coin
    /// ⚠️ DEPRECATED: Use coin::destroy_zero() directly
    public fun destroy_zero_coin(coin: Coin<CMTAT>) {
        coin::destroy_zero(coin)
    }

    /// Transfer coin to recipient
    /// ⚠️ DEPRECATED: Use transfer::public_transfer() directly
    public fun transfer_coin(coin: Coin<CMTAT>, to: address) {
        iota::transfer::public_transfer(coin, to)
    }

    /// Mint coins using treasury cap
    /// ⚠️ DEPRECATED: Use coin::mint() directly
    public fun mint(
        treasury_cap: &mut TreasuryCap<CMTAT>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<CMTAT> {
        coin::mint(treasury_cap, amount, ctx)
    }

    /// Burn coins using treasury cap
    /// ⚠️ DEPRECATED: Use coin::burn() directly
    public fun burn(
        treasury_cap: &mut TreasuryCap<CMTAT>,
        coin: Coin<CMTAT>
    ) {
        coin::burn(treasury_cap, coin);
    }

    /// Get coin value
    /// ⚠️ DEPRECATED: Use coin::value() directly
    public fun coin_value(coin: &Coin<CMTAT>): u64 {
        coin::value(coin)
    }
}
