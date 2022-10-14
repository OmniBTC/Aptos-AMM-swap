// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module swap::interface {
    use std::signer;
    use std::vector;

    use aptos_framework::coin;
    use aptos_std::comparator::{Self, Result};
    use aptos_std::type_info;
    use lp::lp_coin::LP;

    use swap::controller;
    use swap::implements;

    const ERR_NOT_COIN: u64 = 100;
    const ERR_THE_SAME_COIN: u64 = 101;
    const ERR_EMERGENCY: u64 = 102;
    const ERR_INSUFFICIENT_X_AMOUNT: u64 = 103;
    const ERR_INSUFFICIENT_Y_AMOUNT: u64 = 104;
    const ERR_MUST_BE_ORDER: u64 = 105;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 106;

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

    /// Initialize swap
    public entry fun initialize_swap(
        swap_admin: &signer,
        controller: address,
        beneficiary: address,
    ) {
        implements::initialize_swap(swap_admin, controller, beneficiary);
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
        assert!(is_order<X, Y>(), ERR_MUST_BE_ORDER);

        let (optimal_x, optimal_y) = implements::calc_optimal_coin_values<X, Y>(
            coin_x_val,
            coin_y_val,
        );

        assert!(optimal_x >= coin_x_val_min, ERR_INSUFFICIENT_X_AMOUNT);
        assert!(optimal_y >= coin_y_val_min, ERR_INSUFFICIENT_Y_AMOUNT);

        let coin_x_opt = coin::withdraw<X>(account, optimal_x);
        let coin_y_opt = coin::withdraw<Y>(account, optimal_y);

        let lp_coins = implements::mint<X, Y>(
            coin_x_opt,
            coin_y_opt,
        );

        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<LP<X, Y>>(account_addr)) {
            coin::register<LP<X, Y>>(account);
        };
        coin::deposit(account_addr, lp_coins);
    }

    public entry fun remove_liquidity<X, Y>(
        account: &signer,
        lp_val: u64,
        min_x_out_val: u64,
        min_y_out_val: u64,
    ) {
        assert!(!controller::is_emergency(), ERR_EMERGENCY);
        assert!(is_order<X, Y>(), ERR_MUST_BE_ORDER);
        let lp_coins = coin::withdraw<LP<X, Y>>(account, lp_val);
        let (coin_x, coin_y) = implements::burn<X, Y>(lp_coins);

        assert!(coin::value(&coin_x) >= min_x_out_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM);
        assert!(coin::value(&coin_y) >= min_y_out_val, ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM);

        let account_addr = signer::address_of(account);
        coin::deposit(account_addr, coin_x);
        coin::deposit(account_addr, coin_y);
    }

    public entry fun swap<X, Y>(
        account: &signer,
        coin_in_value: u64,
        coin_out_min_value: u64,
    ) {
        assert!(!controller::is_emergency(), ERR_EMERGENCY);

        if (is_order<X, Y>()) {
            let (reserve_x, reserve_y) = implements::get_reserves_size<X, Y>();
            implements::swap<X, Y>(account, coin_in_value, coin_out_min_value, reserve_x, reserve_y);
        } else {
            let (reserve_y, reserve_x) = implements::get_reserves_size<Y, X>();
            implements::swap<Y, X>(account, coin_in_value, coin_out_min_value, reserve_y, reserve_x);
        };
    }
}
