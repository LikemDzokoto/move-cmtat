/// Base Component - Core ERC20 Functionality
/// Provides the foundational token operations for all CMTAT variants
module move_cmtat::base {
    use std::string::String;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};

    /// Errors
    const EInsufficientBalance: u64 = 0;
    const EUnauthorized: u64 = 1;
    const EInvalidAmount: u64 = 2;

    /// Token metadata and state
    public struct TokenInfo has key, store {
        id: UID,
        name: String,
        symbol: String,
        decimals: u8,
        total_supply: u64,
        terms: String,
        information: String,
        token_id: String,
    }

    /// Balance tracking
    public struct Balances has key, store {
        id: UID,
        balances: Table<address, u64>,
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
            total_supply: 0,
            terms: std::string::utf8(b""),
            information: std::string::utf8(b""),
            token_id: std::string::utf8(b""),
        }
    }

    /// Initialize balances table
    public fun init_balances(ctx: &mut TxContext): Balances {
        Balances {
            id: object::new(ctx),
            balances: table::new(ctx),
        }
    }

    /// Get balance of an address
    public fun balance_of(balances: &Balances, account: address): u64 {
        if (table::contains(&balances.balances, account)) {
            *table::borrow(&balances.balances, account)
        } else {
            0
        }
    }

    /// Batch balance query (matching Cairo implementation)
    public fun batch_balance_of(balances: &Balances, accounts: vector<address>): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(&accounts);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            vector::push_back(&mut result, balance_of(balances, account));
            i = i + 1;
        };
        
        result
    }

    /// Update balance
    public fun update_balance(balances: &mut Balances, account: address, new_balance: u64) {
        if (table::contains(&balances.balances, account)) {
            let balance_ref = table::borrow_mut(&mut balances.balances, account);
            *balance_ref = new_balance;
        } else {
            table::add(&mut balances.balances, account, new_balance);
        }
    }

    /// Information getters
    public fun name(info: &TokenInfo): String { info.name }
    public fun symbol(info: &TokenInfo): String { info.symbol }
    public fun decimals(info: &TokenInfo): u8 { info.decimals }
    public fun total_supply(info: &TokenInfo): u64 { info.total_supply }
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

    /// Update total supply
    public fun increase_total_supply(info: &mut TokenInfo, amount: u64) {
        info.total_supply = info.total_supply + amount;
    }

    public fun decrease_total_supply(info: &mut TokenInfo, amount: u64) {
        assert!(info.total_supply >= amount, EInsufficientBalance);
        info.total_supply = info.total_supply - amount;
    }
}
