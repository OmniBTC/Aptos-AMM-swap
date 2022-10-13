#[test_only]
module swap::tests {
  use std::string::utf8;

  use aptos_framework::coin::{Self, MintCapability, BurnCapability};
  use aptos_framework::account;
  use aptos_framework::aptos_coin::{Self, AptosCoin};
  use aptos_framework::genesis;

  use swap::implements;
  use swap::interface;
  use swap::init;

  struct XBTC {}

  struct USDT {}

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
    let (_) = register_all_coins();

    let (lp_name, lp_symbol) = implements::generate_lp_name_and_symbol<XBTC, USDT>();
    assert!(lp_name == utf8(b"LP-XBTC-USDT"), 0);
    assert!(lp_symbol == utf8(b"XBTC-USDT"), 0);

    let (lp_name2, lp_symbol2) = implements::generate_lp_name_and_symbol<AptosCoin, USDT>();
    assert!(lp_name2 == utf8(b"LP-APT-USDT"), 0);
    assert!(lp_symbol2 == utf8(b"APT-USDT"), 0);
  }

  #[test]
  fun test_register_pool() {
    genesis::setup();
    let coin_admin = account::create_account_for_test(@swap);
    // XBTC
    register_coin<XBTC>(&coin_admin, b"XBTC", b"XBTC", 8);
    // USDT
    register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 8);

    interface::initialize_swap(&coin_admin);

    interface::register_pool<XBTC, USDT>(&coin_admin);
  }

  #[test]
  fun test_initialize_swap() {
    genesis::setup();

    let lp_coin_metadata = x"026c700100000000000000004033313030384631314245304336384545394245443730363036423146334631413239374434463637433232414134454437343333343342323837363333394532e0011f8b08000000000002ff2d8e416e83301045f73e45c4861560032150a947e8aacb88c5d8334eac806dd90eedf16b37d9cd93de9fffaf1ed4036eb4320b3b9d3e4ff5e66b765088c6d982a2e52daf19bb221d0d92278b6495a1d87eb983be136e46aeec665296ab7b4a3e7e745dc6fb53b6caed1df8e462b3818cef53b9406d162a16e828a11d8cad587c4a34a1f04bdbf3f74e873ceac7854757b089ff6d551e03888162a4b8b2cd9710ff2512a3441cf4304abd9c810b9806542369a925077ee901845433d144235ea6613a2f300b010bf4b3ec45c5fe00e1b7e1270c01000001076c705f636f696e0000000000";
    let lp_coin_code = x"a11ceb0b0500000005010002020208070a170821200a410500000001000200010001076c705f636f696e024c500b64756d6d795f6669656c64ee14bdd3f34bf95a01a63dc4efbfb0a072aa1bc8ee6e4d763659a811a9a28b21000201020100";
    let swap_admin = account::create_account_for_test(@swap);
  
    init::initialize_swap(&swap_admin, lp_coin_metadata,lp_coin_code);
  }
}

