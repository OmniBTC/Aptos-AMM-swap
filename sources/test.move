#[test_only]
module swap::tests {
  use std::string::utf8;

  use aptos_framework::coin::{Self, MintCapability, BurnCapability};
  use aptos_framework::account;

  use swap::implements;

  struct XBTC {}

  struct USDT {}

  struct USDC {}

  struct Capabilities<phantom CoinType> has key {
    mint_cap: MintCapability<CoinType>,
    burn_cap: BurnCapability<CoinType>,
  }

  fun register_coin<CoinType>(coin_admin: &signer,
                              name: vector<u8>,
                              symbol: vector<u8>,
                              decimals: u8) {
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
  fun register_all_coins() {
    let coin_admin = account::create_account_for_test(@swap); // should used @test_coin_admin
    // XBTC
    register_coin<XBTC>(&coin_admin, b"XBTC", b"XBTC", 8);
    // USDT
    register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 8);
    // USDC
    register_coin<USDC>(&coin_admin, b"USDC", b"USDC", 8);
  }

  #[test]
  fun test_generate_lp_name_and_symbol() {
    register_all_coins();
    let (lp_name, lp_symbol) = implements::generate_lp_name_and_symbol<XBTC, USDT>();

    assert!(lp_name == utf8(b"LP-XBTC-USDT"), 0);
    assert!(lp_symbol == utf8(b"XBTC-USDT"), 0);
  }
}
