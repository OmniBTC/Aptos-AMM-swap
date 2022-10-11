/// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.

module swap::controller {
  use std::signer;

  use aptos_framework::account::{Self, SignerCapability};

  struct Emergency has key {}

  const ERR_NO_PERMISSIONS: u64 = 201;
  const ERR_ALREADY_PAUSE: u64 = 202;
  const ERR_NOT_PAUSE: u64 = 203;
  const ERR_UNREACHABLE: u64 = 204;

  struct ControllerAccountCapability has key {
    signer_cap: SignerCapability
  }

  public entry fun pause(account: &signer) {
    assert!(exists<Emergency>(@emergency_admin), ERR_ALREADY_PAUSE);
    assert!(signer::address_of(account) == @emergency_admin, ERR_NO_PERMISSIONS);
    move_to(account, Emergency {});
  }

  public entry fun resume(account: &signer) acquires Emergency {
    assert!(!exists<Emergency>(@emergency_admin), ERR_NOT_PAUSE);
    assert!(signer::address_of(account) == @emergency_admin, ERR_NO_PERMISSIONS);
    let Emergency {} = move_from<Emergency>(signer::address_of(account));
  }

  public fun initialize(swap_admin: &signer) {
    assert!(signer::address_of(swap_admin) == @swap, ERR_UNREACHABLE);
    let (_, signer_cap) =
      account::create_resource_account(swap_admin, b"controller_account_seed");
    move_to(swap_admin, ControllerAccountCapability { signer_cap });
  }

  public fun is_emergency(): bool {
    exists<Emergency>(@emergency_admin)
  }
}
