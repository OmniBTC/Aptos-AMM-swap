
module swap::lp {
  /// LP coin type for swap.
  struct LP<phantom X, phantom Y> {}
}

module swap::implements {
  use std::string::{Self, String};

  use aptos_framework::coin::{Self, Coin};
  use aptos_framework::account::{Self, SignerCapability};

  use swap::lp::LP;

  const ERR_POOL_EXISTS_FOR_PAIR: u64 = 300;
  const SYMBOL_PREFIX_LENGTH: u64 = 4;

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
  }
}
