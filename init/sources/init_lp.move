// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module swap::init {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 305;

    struct CapabilityStorage has key { signer_cap: SignerCapability }

    public entry fun initialize_swap(
        swap_admin: &signer,
        metadata: vector<u8>,
        code: vector<u8>
    ) {
        assert!(signer::address_of(swap_admin) == @swap, ERR_NOT_ENOUGH_PERMISSIONS);

        // see test_swap_pool_account
        let (lp_acc, signer_cap) = account::create_resource_account(
            swap_admin,
            b"swap_account_seed"
        );

        aptos_framework::code::publish_package_txn(&lp_acc, metadata, vector[code]);

        move_to(swap_admin, CapabilityStorage { signer_cap });
    }

    public fun retrieve_signer_cap(
        swap_admin: &signer
    ): SignerCapability acquires CapabilityStorage {
        assert!(signer::address_of(swap_admin) == @swap, ERR_NOT_ENOUGH_PERMISSIONS);
        let CapabilityStorage { signer_cap } =
            move_from<CapabilityStorage>(signer::address_of(swap_admin));
        signer_cap
    }
}
