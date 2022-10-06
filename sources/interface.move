
module swap::interface {
  use std::signer;
  use std::vector;

  use aptos_framework::coin;
  use aptos_std::comparator::{Self, Result};
  use aptos_std::type_info;

  use swap::implements;
  use swap::controller;

  const ERR_NOT_COIN: u64 = 100;
  const ERR_THE_SAME_COIN: u64 = 101;
  const ERR_EMERGENCY: u64 = 102;

  /// Compare two coins, 'X' and 'Y'.
  fun compare<X, Y>(): Result {
    let x_info = type_info::type_of<X>();
    let x_compare = &mut type_info::struct_name(&x_info);
    vector::append(x_compare, type_info::module_name(&x_info));
    
    let y_info = type_info::type_of<Y>();
    let y_compare = &mut type_info::struct_name(&y_info);
    vector::append(y_compare, type_info::module_name(&y_info));

    let comp = comparator::compare(x_compare, y_compare);
    if (!comparator::is_equal(&comp)) return comp;

    let x_address = type_info::account_address(&x_info);
    let y_address = type_info::account_address(&y_info);
    comparator::compare(&x_address, &y_address)
  }

  /// Register a new liquidity pool for 'X'/'Y' pair.
  public entry fun register_pool<X, Y>(account: &signer) {
    assert!(!controller::is_emergency(), ERR_EMERGENCY);
    assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN); 
    assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);

    let comp = compare<X, Y>();
    assert!(!comparator::is_equal(&comp), ERR_THE_SAME_COIN);
    
    if (comparator::is_smaller_than(&comp)) { 
      implements::register_pool<X, Y>(account);
    } else {
      implements::register_pool<Y, X>(account);
    }
  }
}
