// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module swap::implements {
    use std::option;
    use std::signer;
    use std::string::{Self, String};

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::debug;
    use aptos_framework::timestamp;
    use lp::lp_coin::LP;

    use swap::event;
    use swap::init;
    use swap::math;

    friend swap::interface;
    friend swap::controller;

    const ERR_POOL_EXISTS_FOR_PAIR: u64 = 300;
    const ERR_POOL_DOES_NOT_EXIST: u64 = 301;
    const ERR_POOL_IS_LOCKED: u64 = 302;
    const ERR_INCORRECT_BURN_VALUES: u64 = 303;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 304;
    const ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE: u64 = 306;
    const ERR_LIQUID_NOT_ENOUGH: u64 = 307;
    const ERR_SWAP_NOT_INITIALIZE: u64 = 308;
    const ERR_U64_OVERFLOW: u64 = 309;
    const MINIMAL_LIQUIDITY: u64 = 310;

    const SYMBOL_PREFIX_LENGTH: u64 = 4;
    const FEE_MULTIPLIER: u64 = 30;
    const FEE_SCALE: u64 = 10000;
    const U64_MAX: u64 = 18446744073709551615;


    /// Generate LP coin name and symbol for pair `X`/`Y`.
    /// ```
    /// name = "LP-" + symbol<X>() + "-" + symbol<Y>();
    /// symbol = symbol<X>()[0:4] + "-" + symbol<Y>()[0:4];
    /// ```
    /// For example, for `LP<BTC, USDT>`,
    /// the result will be `(b"LP-BTC-USDT", b"BTC-USDT")`
    public fun generate_lp_name_and_symbol<X, Y>(): (String, String) {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LP-");
        string::append(&mut lp_name, coin::symbol<X>());
        string::append_utf8(&mut lp_name, b"-");
        string::append(&mut lp_name, coin::symbol<Y>());

        let lp_symbol = string::utf8(b"");
        string::append(&mut lp_symbol, coin_symbol_prefix<X>());
        string::append_utf8(&mut lp_symbol, b"-");
        string::append(&mut lp_symbol, coin_symbol_prefix<Y>());

        (lp_name, lp_symbol)
    }

    fun coin_symbol_prefix<CoinType>(): String {
        let symbol = coin::symbol<CoinType>();
        let prefix_length = SYMBOL_PREFIX_LENGTH;
        if (string::length(&symbol) < SYMBOL_PREFIX_LENGTH) {
            prefix_length = string::length(&symbol);
        };
        string::sub_string(&symbol, 0, prefix_length)
    }

    /// Liquidity pool with reserves.
    struct LiquidityPool<phantom X, phantom Y> has key {
        coin_x: Coin<X>,
        // coin x reserve.
        coin_y: Coin<Y>,
        // coin y reserve.
        timestamp: u64,
        // last block timestamp.
        x_cumulative: u128,
        // last price x cumulative.
        y_cumulative: u128,
        // last price y cumulative.
        lp_mint_cap: coin::MintCapability<LP<X, Y>>,
        lp_burn_cap: coin::BurnCapability<LP<X, Y>>,
        locked: bool,
    }

    struct Config has key {
        pool_cap: SignerCapability,
        controller: address
    }

    fun pool_account(): signer acquires Config {
        assert!(exists<Config>(@swap), ERR_SWAP_NOT_INITIALIZE);

        let config = borrow_global<Config>(@swap);
        account::create_signer_with_capability(&config.pool_cap)
    }

    fun pool_address(): address acquires Config {
        assert!(exists<Config>(@swap), ERR_SWAP_NOT_INITIALIZE);

        let config = borrow_global<Config>(@swap);
        account::get_signer_capability_address(&config.pool_cap)
    }

    public(friend) fun controller(): address acquires Config {
        assert!(exists<Config>(@swap), ERR_SWAP_NOT_INITIALIZE);

        borrow_global<Config>(@swap).controller
    }

    public(friend) fun initialize_swap(
        swap_admin: &signer,
        controller: address,
    ) {
        assert!(signer::address_of(swap_admin) == @swap, ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE);

        let pool_cap = init::retrieve_signer_cap(swap_admin);
        let pool_account = account::create_signer_with_capability(&pool_cap);

        move_to(swap_admin, Config { pool_cap, controller });

        event::initialize(&pool_account);
    }

    // 'X', 'Y' must ordered.
    public(friend) fun register_pool<X, Y>(account: &signer) acquires Config {
        let pool_account = pool_account();
        let pool_address = signer::address_of(&pool_account);

        assert!(!exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_EXISTS_FOR_PAIR);

        let (lp_name, lp_symbol) = generate_lp_name_and_symbol<X, Y>();

        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y>>(&pool_account, lp_name, lp_symbol, 6, true);
        coin::destroy_freeze_cap(lp_freeze_cap);

        let pool = LiquidityPool<X, Y> {
            coin_x: coin::zero<X>(),
            coin_y: coin::zero<Y>(),
            timestamp: 0,
            x_cumulative: 0,
            y_cumulative: 0,
            lp_mint_cap,
            lp_burn_cap,
            locked: false,
        };
        move_to(&pool_account, pool);

        event::created_event<X, Y>(pool_address, signer::address_of(account));
    }

    public fun get_reserves_size<X, Y>(): (u64, u64) acquires LiquidityPool, Config {
        let pool_address = pool_address();

        assert!(exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y>>(pool_address);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

        let x_reserve = coin::value(&pool.coin_x);
        let y_reserve = coin::value(&pool.coin_y);

        (x_reserve, y_reserve)
    }

    public(friend) fun mint<X, Y>(
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
    ): Coin<LP<X, Y>>  acquires LiquidityPool, Config {
        let pool_address = pool_address();
        assert!(exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_DOES_NOT_EXIST);

        let x_provided_val = coin::value<X>(&coin_x);
        let y_provided_val = coin::value<Y>(&coin_y);

        let lp_coins_total = option::extract(&mut coin::supply<LP<X, Y>>());
        let provided_liq = if (0 == lp_coins_total) {
        let initial_liq = math::sqrt(x_provided_val) * math::sqrt(y_provided_val);
        assert!(initial_liq > MINIMAL_LIQUIDITY, ERR_LIQUID_NOT_ENOUGH); 
            initial_liq - MINIMAL_LIQUIDITY
        } else {
            let (reserve_x, reserve_y) = get_reserves_size<X, Y>(); 
            let x_liq = (lp_coins_total as u128) * (x_provided_val as u128) / (reserve_x as u128);
            let y_liq = (lp_coins_total as u128) * (y_provided_val  as u128) / (reserve_y as u128);
            if (x_liq < y_liq) {
                assert!(x_liq < (U64_MAX as u128), ERR_U64_OVERFLOW);
                (x_liq as u64)
            } else {
                assert!(y_liq < (U64_MAX as u128), ERR_U64_OVERFLOW);
                (y_liq as u64)
            }
        };

        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        coin::merge(&mut pool.coin_x, coin_x);
        coin::merge(&mut pool.coin_y, coin_y);

        event::added_event<X, Y>(pool_address, x_provided_val, y_provided_val, provided_liq);
        update_oracle<X, Y>(pool_address, pool);

        let lp_coins = coin::mint<LP<X, Y>>(provided_liq, &pool.lp_mint_cap);

        lp_coins
    }

    public(friend) fun burn<X, Y>(
        lp_coins: Coin<LP<X, Y>>,
    ): (Coin<X>, Coin<Y>) acquires LiquidityPool, Config {
        let pool_address = pool_address();
        assert!(exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

        let burned_lp_coins_val = coin::value(&lp_coins);
        let x_reserve_val = coin::value(&pool.coin_x);
        let y_reserve_val = coin::value(&pool.coin_y);

        debug::print(&1);
        let lp_coins_total = option::extract(&mut coin::supply<LP<X, Y>>());
        debug::print(&2);
        let x_tmp = ((x_reserve_val * burned_lp_coins_val) as u128);
        let x_to_return_val = ((x_tmp / lp_coins_total) as u64);
        let y_tmp = ((y_reserve_val * burned_lp_coins_val) as u128);
        let y_to_return_val = ((y_tmp / lp_coins_total) as u64);
        assert!(x_to_return_val > 0 && y_to_return_val > 0, ERR_INCORRECT_BURN_VALUES);

        let x_coin_to_return = coin::extract(&mut pool.coin_x, x_to_return_val);
        let y_coin_to_return = coin::extract(&mut pool.coin_y, y_to_return_val);

        event::removed_event<X, Y>(pool_address, x_to_return_val, y_to_return_val, burned_lp_coins_val);
        update_oracle<X, Y>(pool_address, pool);

        coin::burn(lp_coins, &pool.lp_burn_cap);

        (x_coin_to_return, y_coin_to_return)
    }

    /// if x is true, return coin Y else return coin X.
    public fun get_amout_out<X, Y>(
        amout_in: u64,
        x: bool
    ): u64 acquires LiquidityPool, Config {
        let (reserve_x, reserve_y) = get_reserves_size<X, Y>();

        let (fee_pct, fee_scale) = (FEE_MULTIPLIER, FEE_SCALE);
        let fee_multiplier = fee_scale - fee_pct;

        let coin_in_val_after_fees = amout_in * fee_multiplier;
        if (x) {
            let new_reserve_in = reserve_x * fee_scale + coin_in_val_after_fees;
            return reserve_y * coin_in_val_after_fees / new_reserve_in
        } else {
            let new_reserve_in = reserve_y * fee_scale + coin_in_val_after_fees;
            return reserve_x * coin_in_val_after_fees / new_reserve_in
        }
    }

    public(friend) fun swap_x<X, Y>(
        coin_in: Coin<X>,
        coin_out_min_val: u64,
    ): Coin<Y> acquires LiquidityPool, Config {
        let coin_in_val = coin::value(&coin_in);
        let coin_out_val = get_amout_out<X, Y>(coin_in_val, true);
        assert!(coin_out_val >= coin_out_min_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM, );

        let pool_address = pool_address();
        assert!(exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_DOES_NOT_EXIST);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

        coin::merge(&mut pool.coin_x, coin_in);

        let y_swapped = coin::extract(&mut pool.coin_y, coin_out_val);

        // let x_res_new_after_fee = coin::value(&pool.coin_x) * FEE_SCALE - coin_in_val * FEE_MULTIPLIER;

        let fee_multiplier = FEE_MULTIPLIER / 5; // 20% fee to swap fundation.
        let x_fee_val = coin_in_val * fee_multiplier / FEE_SCALE;
        let x_in = coin::extract(&mut pool.coin_x, x_fee_val);
        coin::deposit(pool_address, x_in);
        event::swapped_event<X, Y>(pool_address, coin_in_val, 0, 0, coin_out_val);
        update_oracle<X, Y>(pool_address, pool);

        y_swapped
    }

    public(friend) fun swap_y<X, Y>(
        coin_in: Coin<Y>,
        coin_out_min_val: u64,
    ): Coin<X> acquires LiquidityPool, Config {
        let coin_in_val = coin::value(&coin_in);
        let coin_out_val = get_amout_out<X, Y>(coin_in_val, false);
        assert!(coin_out_val >= coin_out_min_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM, );

        let pool_address = pool_address();
        assert!(exists<LiquidityPool<X, Y>>(pool_address), ERR_POOL_DOES_NOT_EXIST);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

        coin::merge(&mut pool.coin_y, coin_in);

        let x_swapped = coin::extract(&mut pool.coin_x, coin_out_val);

        let fee_multiplier = FEE_MULTIPLIER / 5; // 20% fee to swap fundation.
        let y_fee_val = coin_in_val * fee_multiplier / FEE_SCALE;
        let y_in = coin::extract(&mut pool.coin_y, y_fee_val);
        coin::deposit(pool_address, y_in);
        event::swapped_event<X, Y>(pool_address, 0, coin_out_val, coin_in_val, 0);
        update_oracle<X, Y>(pool_address, pool);

        x_swapped
    }

    fun update_oracle<X, Y>(
        pool_address: address,
        pool: &mut LiquidityPool<X, Y>,
    ) {
        let x_reserve = coin::value(&pool.coin_x);
        let y_reserve = coin::value(&pool.coin_y);

        let last_block_timestamp = pool.timestamp;
        let block_timestamp = timestamp::now_seconds();
        let time_elapsed = block_timestamp - last_block_timestamp;

        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            pool.x_cumulative = (time_elapsed as u128) * (x_reserve as u128) / (y_reserve as u128);
            pool.y_cumulative = (time_elapsed as u128) * (y_reserve as u128) / (x_reserve as u128);

            event::update_oracle_event<X, Y>(pool_address, pool.x_cumulative, pool.y_cumulative);
        };

        pool.timestamp = block_timestamp;
    }
}
