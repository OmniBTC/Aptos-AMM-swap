
module swap::interface {
  use std::signer;
  use std::vector;

  use aptos_framework::coin;
  use aptos_std::comparator::{Self, Result};
  use aptos_std::type_info;

  use swap::implements;
  use swap::controller;
  use swap::lp::LP;

  const ERR_NOT_COIN: u64 = 100;
  const ERR_THE_SAME_COIN: u64 = 101;
  const ERR_EMERGENCY: u64 = 102;
  const ERR_INSUFFICIENT_X_AMOUNT: u64 = 103;
  const ERR_INSUFFICIENT_Y_AMOUNT: u64 = 104;

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

   fun is_order<X, Y>(): bool {
     let comp = compare<X, Y>();
     assert!(!comparator::is_equal(&comp), ERR_THE_SAME_COIN);

     if (comparator::is_smaller_than(&comp)) {
       true
     } else {
       false
     }
   }

   public fun calc_optimal_coin_values<X, Y>(
     x_desired: u64,
     y_desired: u64,
     x_min: u64,
     y_min: u64
   ): (u64, u64) {
     let (reserves_x, reserves_y) = implements::get_reserves_size<X, Y>();
     if (reserves_x == 0 && reserves_y == 0) {
       return (x_desired, y_desired)
     } else {
       let y_returned = reserves_y / reserves_x * x_desired;
       if (y_returned <= y_desired) {
         return (x_desired, y_returned)
       } else {
         let x_returned = reserves_x / reserves_y * y_desired;
         return (x_returned, y_desired)
       }
     } 
   }
  

  /// Register a new liquidity pool for 'X'/'Y' pair.
  public entry fun register_pool<X, Y>(account: &signer) {
    assert!(!controller::is_emergency(), ERR_EMERGENCY);
    assert!(coin::is_coin_initialized<X>(), ERR_NOT_COIN); 
    assert!(coin::is_coin_initialized<Y>(), ERR_NOT_COIN);
    
    if (is_order<X, Y>()) { 
      implements::register_pool<X, Y>(account);
    } else {
      implements::register_pool<Y, X>(account);
    }
  }

  public entry fun add_liquidity<X, Y>(
    account: &signer,
    coin_x_val: u64,
    coin_x_val_min: u64,
    coin_y_val: u64,
    coin_y_val_min: u64,
  ) {
    assert!(!controller::is_emergency(), ERR_EMERGENCY);
    assert!(coin_x_val >= coin_x_val_min, ERR_INSUFFICIENT_X_AMOUNT);
    assert!(coin_y_val >= coin_y_val_min, ERR_INSUFFICIENT_Y_AMOUNT);

    let coin_x = coin::withdraw<X>(account, coin_x_val);
    let coin_y = coin::withdraw<Y>(account, coin_y_val);

    let account_addr = signer::address_of(account);
      if (is_order<X, Y>()) {
        if (!coin::is_account_registered<LP<X, Y>>(account_addr)) {
          coin::register<LP<X, Y>>(account);
        };

        let (optimal_x, optimal_y) = calc_optimal_coin_values<X, Y>(
            coin_x_val,
            coin_y_val,
            coin_x_val_min,
            coin_y_val_min,
          );
        let coin_x_opt = coin::extract(&mut coin_x, optimal_x);
        let coin_y_opt = coin::extract(&mut coin_y, optimal_y);
        let lp_coins = implements::mint<X, Y>(
          coin_x_opt,
          coin_y_opt,
        );
        coin::deposit(account_addr, lp_coins);
      } else {
        if (!coin::is_account_registered<LP<Y, X>>(account_addr)) {
          coin::register<LP<Y, X>>(account);
        };
        let (optimal_y, optimal_x) = calc_optimal_coin_values<Y, X>(
            coin_y_val,
            coin_x_val,
            coin_y_val_min,
            coin_x_val_min,
          );
        let coin_x_opt = coin::extract(&mut coin_x, optimal_x);
        let coin_y_opt = coin::extract(&mut coin_y, optimal_y);
        let lp_coins = implements::mint<Y, X>(
          coin_y_opt,
          coin_x_opt,
        );
        coin::deposit(account_addr, lp_coins);
      };

     coin::deposit(account_addr, coin_x);
     coin::deposit(account_addr, coin_y);
   }
}
