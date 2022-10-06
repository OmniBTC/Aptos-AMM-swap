
module swap::controller {
  use std::signer;

  struct Emergency has key {}

  const ERR_NO_PERMISSIONS: u64 = 201;
  const ERR_ALREADY_PAUSE: u64 = 202;
  const ERR_NOT_PAUSE: u64 = 203;

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

  public fun is_emergency(): bool {
    exists<Emergency>(@emergency_admin)
  }
}
