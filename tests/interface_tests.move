#[test_only]
module swap::interface_tests {
    use std::signer;
    use std::string::{utf8};
    use aptos_framework::coin::{Self, MintCapability};
    use aptos_framework::account;
    use aptos_framework::genesis;

    use lp::lp_coin::LP;
    use swap::math;
    use swap::implements;
    use swap::interface;

    struct XBTC {}

    struct USDT {}

    #[test_only]
    fun register_coin<CoinType>(
        coin_admin: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8
    ): MintCapability<CoinType> {
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<CoinType>(
                coin_admin,
                utf8(name),
                utf8(symbol),
                decimals,
                true);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);

        mint_cap
    }

    #[test_only]
    fun register_pool_with_liquidity(
        account: &signer,
        usdt_val: u64,
        xbtc_val: u64
    ) {
        genesis::setup();

        let coin_admin = account::create_account_for_test(@swap);
        let account_address = signer::address_of(account);
        let admin_address = signer::address_of(&coin_admin);

        // USDT
        coin::register<USDT>(account);
        coin::register<USDT>(&coin_admin);
        let usdt_mint_cap = register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 8);
        coin::deposit(account_address, coin::mint<USDT>(usdt_val, &usdt_mint_cap));
        coin::deposit(admin_address, coin::mint<USDT>(usdt_val, &usdt_mint_cap));
        coin::destroy_mint_cap(usdt_mint_cap);
        assert!(coin::balance<USDT>(account_address) == usdt_val, 1);
        assert!(coin::balance<USDT>(admin_address) == usdt_val, 2);

        // XBTC
        coin::register<XBTC>(account);
        coin::register<XBTC>(&coin_admin);
        let xbtc_mint_cap = register_coin<XBTC>(&coin_admin, b"XBTC", b"XBTC", 8);
        coin::deposit(account_address, coin::mint<XBTC>(xbtc_val, &xbtc_mint_cap));
        coin::deposit(admin_address, coin::mint<XBTC>(xbtc_val, &xbtc_mint_cap));
        coin::destroy_mint_cap(xbtc_mint_cap);
        assert!(coin::balance<XBTC>(account_address) == xbtc_val, 3);
        assert!(coin::balance<XBTC>(admin_address) == xbtc_val, 4);

        implements::initialize_swap_for_test(
            &coin_admin,
            admin_address,
            admin_address
        );

        interface::register_pool<XBTC, USDT>(&coin_admin);

        interface::add_liquidity<USDT, XBTC>(
            &coin_admin,
            usdt_val,
            1,
            xbtc_val,
            1
        );

        assert!(coin::balance<XBTC>(admin_address) == 0, 5);
        assert!(coin::balance<USDT>(admin_address) == 0, 6);

        assert!(
            coin::balance<LP<USDT, XBTC>>(admin_address)
                == math::sqrt(xbtc_val) * math::sqrt(usdt_val) - 1000,
            coin::balance<LP<USDT, XBTC>>(admin_address)
        );
    }

    #[test(user = @0x123)]
    fun test_add_liquidity(
        user: address
    ) {
        let user_account = account::create_account_for_test(user);
        let usdt_val = 1900000000000;
        let xbtc_val = 100000000;

        register_pool_with_liquidity(
            &user_account,
            usdt_val,
            xbtc_val,
        );

        assert!(coin::balance<USDT>(user) == usdt_val, 1);
        assert!(coin::balance<XBTC>(user) == xbtc_val, 2);

        interface::add_liquidity<USDT, XBTC>(
            &user_account,
            usdt_val / 100,
            1,
            xbtc_val / 100,
            1
        );

        assert!(coin::balance<USDT>(user) == usdt_val - usdt_val / 100, 3);
        assert!(coin::balance<XBTC>(user) == xbtc_val - xbtc_val / 100, 4);
        assert!(
            137840390 == coin::balance<LP<USDT,XBTC>>(user),
            coin::balance<LP<USDT,XBTC>>(user)
        )
    }

    #[test(user = @0x123)]
    fun test_remove_liquidity(
        user: address
    ) {
        let user_account = account::create_account_for_test(user);
        let usdt_val = 1900000000000;
        let xbtc_val = 100000000;

        register_pool_with_liquidity(
            &user_account,
            usdt_val,
            xbtc_val,
        );

        assert!(coin::balance<USDT>(user) == usdt_val, 1);
        assert!(coin::balance<XBTC>(user) == xbtc_val, 2);

        interface::add_liquidity<USDT, XBTC>(
            &user_account,
            usdt_val / 100,
            1,
            xbtc_val / 100,
            1
        );

        assert!(coin::balance<USDT>(user) == usdt_val - usdt_val / 100, 3);
        assert!(coin::balance<XBTC>(user) == xbtc_val - xbtc_val / 100, 4);
        assert!(
            coin::balance<LP<USDT,XBTC>>(user) == 137840390,
            coin::balance<LP<USDT,XBTC>>(user)
        );

        interface::remove_liquidity<USDT, XBTC>(
            &user_account,
            13784039,
            1,
            1,
        );

        assert!(
            coin::balance<LP<USDT,XBTC>>(user) == 137840390 - 13784039,
            coin::balance<LP<USDT,XBTC>>(user)
        );

        assert!(
            coin::balance<USDT>(user)
                == usdt_val - usdt_val / 100 + usdt_val / 1000,
            coin::balance<USDT>(user)
        );
        assert!(
            coin::balance<XBTC>(user)
                == xbtc_val - xbtc_val / 100 + xbtc_val / 1000,
            coin::balance<XBTC>(user)
        );
    }

    #[test(user = @0x123)]
    fun test_swap(
        user: address
    ) {
        let user_account = account::create_account_for_test(user);
        let usdt_val = 1900000000000;
        let xbtc_val = 100000000;

        register_pool_with_liquidity(
            &user_account,
            usdt_val,
            xbtc_val,
        );

        assert!(coin::balance<USDT>(user) == usdt_val, 1);
        assert!(coin::balance<XBTC>(user) == xbtc_val, 2);

        interface::add_liquidity<USDT, XBTC>(
            &user_account,
            usdt_val / 100,
            1,
            xbtc_val / 100,
            1
        );

        assert!(coin::balance<USDT>(user) == usdt_val - usdt_val / 100, 3);
        assert!(coin::balance<XBTC>(user) == xbtc_val - xbtc_val / 100, 4);
        assert!(
            137840390 == coin::balance<LP<USDT,XBTC>>(user),
            coin::balance<LP<USDT,XBTC>>(user)
        );

        let (reserve_usdt, reserve_xbtc) = implements::get_reserves_size<USDT, XBTC>();
        let expected_xbtc = implements::get_amount_out(
            (usdt_val / 100 * 997 / 1000),
            reserve_usdt,
            reserve_xbtc
        );

        interface::swap<USDT, XBTC>(
            &user_account,
            usdt_val / 100,
            1
        );

        assert!(
            coin::balance<USDT>(user) == usdt_val - usdt_val / 100 * 2,
            coin::balance<USDT>(user)
        );

        assert!(
            coin::balance<XBTC>(user) == xbtc_val - xbtc_val / 100 + expected_xbtc,
            coin::balance<XBTC>(user)
        );
    }
}
