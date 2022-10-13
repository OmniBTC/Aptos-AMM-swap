#[test_only]
module swap::tests {
  use std::string::utf8;

  use aptos_framework::coin::{Self, MintCapability, BurnCapability};
  use aptos_framework::account;
  use aptos_framework::aptos_coin::{Self, AptosCoin};
  use aptos_framework::genesis;

  use swap::implements;
  use swap::interface;
  use std::signer;

  struct XBTC {}

  struct USDT {}

  struct Capabilities<phantom CoinType> has key {
    mint_cap: MintCapability<CoinType>,
    burn_cap: BurnCapability<CoinType>,
  }

  fun register_coin<CoinType>(
    coin_admin: &signer,
    name: vector<u8>,
    symbol: vector<u8>,
    decimals: u8
  ) {
    let (burn_cap, freeze_cap, mint_cap) =
      coin::initialize<CoinType>(
        coin_admin,
        utf8(name),
        utf8(symbol),
        decimals,
        true);
    coin::destroy_freeze_cap(freeze_cap);

    move_to(coin_admin, Capabilities<CoinType> {
      mint_cap,
      burn_cap,
    });
  }

  #[test_only]
  fun register_all_coins(): signer {
    let coin_admin = account::create_account_for_test(@swap);
    // XBTC
    register_coin<XBTC>(&coin_admin, b"XBTC", b"XBTC", 8);
    // USDT
    register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 8);

    // APT
    let apt_admin = account::create_account_for_test(@0x1);
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&apt_admin);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin_admin
  }

  #[test]
  fun test_generate_lp_name_and_symbol() {
    let _ = register_all_coins();

    let (lp_name, lp_symbol) = implements::generate_lp_name_and_symbol<XBTC, USDT>();
    assert!(lp_name == utf8(b"LP-XBTC-USDT"), 0);
    assert!(lp_symbol == utf8(b"XBTC-USDT"), 0);

    let (lp_name2, lp_symbol2) = implements::generate_lp_name_and_symbol<AptosCoin, USDT>();
    assert!(lp_name2 == utf8(b"LP-APT-USDT"), 0);
    assert!(lp_symbol2 == utf8(b"APT-USDT"), 0);
  }

  #[test(swap = @swap)]
  fun test_register_pool(
    swap: &signer
  ) {
    genesis::setup();

    // XBTC
    register_coin<XBTC>(swap, b"XBTC", b"XBTC", 8);
    // USDT
    register_coin<USDT>(swap, b"USDT", b"USDT", 8);

    interface::initialize_swap(swap, signer::address_of(swap));

    interface::register_pool<XBTC, USDT>(swap);
  }

  #[test]
  fun test_add_liquidity() {
  }
}
