/// Base Component - Core IOTA Native Token Functionality
/// Provides the foundational token operations using IOTA's Coin<T> architecture
module move_cmtat::base {
    use std::string::String;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::coin::{Self, Coin, TreasuryCap};
    use iota::balance::{Self, Balance};

    /// Errors
    const EInsufficientBalance: u64 = 0;
    const EUnauthorized: u64 = 1;
    const EInvalidAmount: u64 = 2;

    /// Phantom type for CMTAT token - used with Coin<CMTAT>
    public struct CMTAT has drop {}

    /// Token metadata (no total_supply - VM tracks via TreasuryCap)
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

    /// Get total supply from TreasuryCap (VM-enforced)
    public fun total_supply(treasury_cap: &TreasuryCap<CMTAT>): u64 {
        coin::total_supply(treasury_cap)
    }

    /// Create treasury cap and initial coins
    public fun create_treasury_cap(ctx: &mut TxContext): TreasuryCap<CMTAT> {
        coin::create_treasury_cap<CMTAT>(ctx)
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
    public fun burn(treasury_cap: &mut TreasuryCap<CMTAT>, coins: Coin<CMTAT>) {
        coin::burn(treasury_cap, coins);
    }

    /// Split coin into two parts
    public fun split_coin(coin: &mut Coin<CMTAT>, amount: u64, ctx: &mut TxContext): Coin<CMTAT> {
        coin::split(coin, amount, ctx)
    }

    /// Join two coins together
    public fun join_coins(coin1: &mut Coin<CMTAT>, coin2: Coin<CMTAT>) {
        coin::join(coin1, coin2);
    }

    /// Get coin value
    public fun coin_value(coin: &Coin<CMTAT>): u64 {
        coin::value(coin)
    }

    /// Transfer coin to recipient
    public fun transfer_coin(coin: Coin<CMTAT>, recipient: address) {
        transfer::public_transfer(coin, recipient);
    }

    /// Zero coin check
    public fun is_zero_coin(coin: &Coin<CMTAT>): bool {
        coin::value(coin) == 0
    }

    /// Destroy zero coin
    public fun destroy_zero_coin(coin: Coin<CMTAT>) {
        coin::destroy_zero(coin);
    }
}
