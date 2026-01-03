/// Base Component - Core IOTA Native Token Functionality (FIXED)
/// NOTE: This module is deprecated - use native Coin<T> directly
module move_cmtat::base {
    use std::string::String;
    use iota::object::{Self, UID};  // ✅ FIX: Add missing imports
    use iota::tx_context::TxContext;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::transfer;

    /// Phantom type for CMTAT token
    public struct CMTAT has drop {}

    /// Token metadata
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
    public fun total_supply(treasury_cap: &TreasuryCap<CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    /// Create treasury cap - wrapper for Coin module functionality
    /// Note: In production, use coin::create_currency for proper initialization
    public fun create_treasury_cap(_ctx: &mut TxContext): TreasuryCap<CMTAT> {
        // This is a placeholder - proper implementation would use coin::create_currency
        // For now, we'll need to pass treasury_cap from coin::create_currency call
        abort 999 // Must be replaced with proper initialization
    }

    /// Destroy a zero-value coin
    public fun destroy_zero_coin(coin: Coin<CMTAT>) {
        coin::destroy_zero(coin)
    }

    /// Transfer coin to recipient
    public fun transfer_coin(coin: Coin<CMTAT>, to: address) {
        iota::transfer::public_transfer(coin, to)
    }

    /// Mint coins using treasury cap
    public fun mint(
        treasury_cap: &mut TreasuryCap<CMTAT>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<CMTAT> {
        coin::mint(treasury_cap, amount, ctx)
    }

    /// Burn coins using treasury cap
    public fun burn(
        treasury_cap: &mut TreasuryCap<CMTAT>,
        coin: Coin<CMTAT>
    ) {
        coin::burn(treasury_cap, coin);
    }

    /// Get coin value
    public fun coin_value(coin: &Coin<CMTAT>): u64 {
        coin::value(coin)
    }
}
