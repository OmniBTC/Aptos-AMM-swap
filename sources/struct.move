/// The data structure that Aptos AMM swap needs to implement.

module swap::lp {
  /// LP coin type for swap.
  struct LP<phantom X, phantom Y> {}
}

module swap::liquidity_pool {
  use aptos_framework::coin::{Self, Coin};
  use swap::lp::LP;

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
}

module swap::event {
  use aptos_std::event;

  /// Liquidity pool created event.
  struct CreatedEvent<phantom X, phantom Y> has drop, store {
    creator: address,
  }

  /// Liquidity pool added event.
  struct AddedEvent<phantom X, phantom Y> has drop, store {
    x_val: u64,
    y_val: u64,
    lp_tokens: u64,
  }

  /// Liquidity pool removed event.
  struct RemovedEvent<phantom X, phantom Y> has drop, store {
    x_val: u64,
    y_val: u64,
    lp_tokens: u64,
  }

  /// Liquidity pool swapped event.
  struct SwappedEvent<phantom X, phantom Y> has drop, store {
    x_in: u64,
    x_out: u64,
    y_in: u64,
    y_out: u64,
  }

  /// Last price oracle.
  struct OracleUpdatedEvent<phantom X, phantom Y> has drop, store {
    x_cumulative: u128, // last price of x cumulative.
    y_cumulative: u128, // last price of y cumulative.
  }

  struct EventsStore<phantom X, phantom Y> has key {
    created_handle: event::EventHandle<CreatedEvent<X, Y>>,
    removed_handle: event::EventHandle<RemovedEvent<X, Y>>,
    added_handle: event::EventHandle<AddedEvent<X, Y>>,
    swapped_handle: event::EventHandle<SwappedEvent<X, Y>>,
    oracle_updated_handle: event::EventHandle<OracleUpdatedEvent<X, Y>>,
  }
}
