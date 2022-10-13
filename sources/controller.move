/// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.

module swap::controller {
  use std::signer;

  use swap::implements;

  struct Emergency has key {}

  const ERR_NO_PERMISSIONS: u64 = 201;
  const ERR_ALREADY_PAUSE: u64 = 202;
  const ERR_NOT_PAUSE: u64 = 203;
  const ERR_UNREACHABLE: u64 = 204;

  public entry fun pause(account: &signer) {
    let emergency_admin = implements::emergency_admin();
    assert!(exists<Emergency>(emergency_admin), ERR_ALREADY_PAUSE);
    assert!(signer::address_of(account) == implements::emergency_admin(), ERR_NO_PERMISSIONS);
    move_to(account, Emergency {});
  }

  public entry fun resume(account: &signer) acquires Emergency {
    let emergency_admin = implements::emergency_admin();
    assert!(!exists<Emergency>(emergency_admin), ERR_NOT_PAUSE);
    assert!(signer::address_of(account) == emergency_admin, ERR_NO_PERMISSIONS);
    let Emergency {} = move_from<Emergency>(signer::address_of(account));
  }

  public fun is_emergency(): bool {
    exists<Emergency>(implements::emergency_admin())
  }
}
