
module swap::lp {
  /// LP coin type for swap.
  struct LP<phantom X, phantom Y> {}
}

module swap::implements {
  use std::string::{Self, String};
  use std::option;

  use aptos_framework::coin::{Self, Coin};
  use aptos_framework::account::{Self, SignerCapability};

  use swap::lp::LP;

  const ERR_POOL_EXISTS_FOR_PAIR: u64 = 300;
  const ERR_POOL_DOES_NOT_EXIST: u64 = 301;
  const ERR_POOL_IS_LOCKED: u64 = 302;
  const ERR_INCORRECT_BURN_VALUES: u64 = 303;
  const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 304;

  const SYMBOL_PREFIX_LENGTH: u64 = 4;
  const FEE_MULTIPLIER: u64 = 30;
  const FEE_SCALE: u64 = 10000;

  /// Generate LP coin name and symbol for pair `X`/`Y`.
  /// ```
  /// name = "LP-" + symbol<X>() + "-" + symbol<Y>();
  /// symbol = symbol<X>()[0:4] + "-" + symbol<Y>()[0:4];
  /// ```
  /// For example, for `LP<BTC, USDT>`,
  /// the result will be `(b"LP-BTC-USDT", b"BTC-USDT")`
  fun generate_lp_name_and_symbol<X, Y>(): (String, String) {
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

  struct PoolAccountCapability has key { signer_cap: SignerCapability }

  /// Liquidity pool with reserves.
  struct LiquidityPool<phantom X, phantom Y> has key {
    coin_x: Coin<X>, // coin x reserve.
    coin_y: Coin<Y>, // coin y reserve.
    timestamp: u64, // last block timestamp.
    x_cumulative: u128, // last price x cumulative.
    y_cumulative: u128, // last price y cumulative.
    lp_mint_cap: coin::MintCapability<LP<X, Y>>,
    lp_burn_cap: coin::BurnCapability<LP<X, Y>>,
    locked: bool,
  }

  // 'X', 'Y' must ordered.
  public fun register_pool<X, Y>(account: &signer) acquires PoolAccountCapability {
    assert!(!exists<LiquidityPool<X, Y>>(@lp_account), ERR_POOL_EXISTS_FOR_PAIR);

    let pool_cap = borrow_global<PoolAccountCapability>(@swap);
    let pool_account = account::create_signer_with_capability(&pool_cap.signer_cap);

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
    // TO DO: event
  }

  public fun get_reserves_size<X, Y>(): (u64, u64) acquires LiquidityPool {
    assert!(exists<LiquidityPool<X, Y>>(@swap_pool_account), ERR_POOL_DOES_NOT_EXIST);

    let pool = borrow_global<LiquidityPool<X, Y>>(@swap_pool_account);
    assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

    let x_reserve = coin::value(&pool.coin_x);
    let y_reserve = coin::value(&pool.coin_y);
    
    (x_reserve, y_reserve) 
  }

  public fun mint<X, Y>(
    coin_x: Coin<X>,
    coin_y: Coin<Y>,
  ): Coin<LP<X, Y>>  acquires LiquidityPool {
    assert!(exists<LiquidityPool<X, Y>>(@swap_pool_account), ERR_POOL_DOES_NOT_EXIST); 
    let (x_reserve_size, y_reserve_size) = get_reserves_size<X, Y>();
    let x_provided_val = coin::value<X>(&coin_x);
    let y_provided_val = coin::value<Y>(&coin_y);

    let provided_liq = x_provided_val * y_provided_val;

    let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_pool_account);
    coin::merge(&mut pool.coin_x, coin_x);
    coin::merge(&mut pool.coin_y, coin_y);

    let lp_coins = coin::mint<LP<X, Y>>(provided_liq, &pool.lp_mint_cap);
    // TO DO: event

    lp_coins
  }

  public fun burn<X, Y>(
    lp_coins: Coin<LP<X, Y>>,
  ): (Coin<X>, Coin<Y>) acquires LiquidityPool {
    assert!(exists<LiquidityPool<X, Y>>(@swap_pool_account), ERR_POOL_DOES_NOT_EXIST);

    let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_pool_account);
    assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

    let burned_lp_coins_val = coin::value(&lp_coins);
    let x_reserve_val = coin::value(&pool.coin_x);
    let y_reserve_val = coin::value(&pool.coin_y);

    let lp_coins_total = option::extract(&mut coin::supply<Coin<LP<X, Y>>>());
    let x_tmp = ((x_reserve_val * burned_lp_coins_val) as u128);
    let x_to_return_val = ((x_tmp / lp_coins_total) as u64);
    let y_tmp = ((y_reserve_val * burned_lp_coins_val) as u128);
    let y_to_return_val = ((y_tmp / lp_coins_total) as u64);
    assert!(x_to_return_val > 0 && y_to_return_val > 0, ERR_INCORRECT_BURN_VALUES);

    let x_coin_to_return = coin::extract(&mut pool.coin_x, x_to_return_val);
    let y_coin_to_return = coin::extract(&mut pool.coin_y, y_to_return_val);

    coin::burn(lp_coins, &pool.lp_burn_cap);

    (x_coin_to_return, y_coin_to_return)
  }

  /// if x is true, return coin Y else return coin X.
  public fun get_amout_out<X, Y>(amout_in: u64, x: bool): u64 acquires LiquidityPool {
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

  public fun swap_x<X, Y>(
    coin_in: Coin<X>,
    coin_out_min_val: u64,
  ): Coin<Y> acquires LiquidityPool {
    let coin_in_val = coin::value(&coin_in);
    let coin_out_val = get_amout_out<X, Y>(coin_in_val, true);
    assert!(coin_out_val >= coin_out_min_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM,);

    assert!(exists<LiquidityPool<X, Y>>(@swap_pool_account), ERR_POOL_DOES_NOT_EXIST);
    let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_pool_account);
    assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

    //let (reserve_x, reserve_y) = get_reserves_size<X, Y>();

    coin::merge(&mut pool.coin_x, coin_in);

    let y_swapped = coin::extract(&mut pool.coin_y, coin_out_val);

    // let x_res_new_after_fee = coin::value(&pool.coin_x) * FEE_SCALE - coin_in_val * FEE_MULTIPLIER;

    let fee_multiplier = FEE_MULTIPLIER / 5; // 20% fee to swap fundation. 
    let x_fee_val = coin_in_val * fee_multiplier / FEE_SCALE;
    let x_in = coin::extract(&mut pool.coin_x, x_fee_val);
    coin::deposit(@swap_pool_account, x_in);
    
    y_swapped
  }

  public fun swap_y<X, Y>(
    coin_in: Coin<Y>,
    coin_out_min_val: u64,
  ): Coin<X> acquires LiquidityPool {
    let coin_in_val = coin::value(&coin_in);
    let coin_out_val = get_amout_out<X, Y>(coin_in_val, false);
    assert!(coin_out_val >= coin_out_min_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM,);

    assert!(exists<LiquidityPool<X, Y>>(@swap_pool_account), ERR_POOL_DOES_NOT_EXIST);
    let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_pool_account);
    assert!(pool.locked == false, ERR_POOL_IS_LOCKED);

    coin::merge(&mut pool.coin_y, coin_in);

    let x_swapped = coin::extract(&mut pool.coin_x, coin_out_val);

    let fee_multiplier = FEE_MULTIPLIER / 5; // 20% fee to swap fundation.
    let y_fee_val = coin_in_val * fee_multiplier / FEE_SCALE;
    let y_in = coin::extract(&mut pool.coin_y, y_fee_val);
    coin::deposit(@swap_pool_account, y_in);

    x_swapped
  }
}
