// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module swap::beneficiary {
    use std::signer;
    use swap::implements::{beneficiary, withdraw_fee};
    use swap::controller::is_emergency;

    const ERR_NO_PERMISSIONS: u64 = 400;
    const ERR_EMERGENCY: u64 = 401;

    /// Transfers fee coin to the beneficiary.
    public entry fun withdraw<Coin>(account: &signer) {
        assert!(!is_emergency(), ERR_EMERGENCY);
        assert!(beneficiary() == signer::address_of(account), ERR_NO_PERMISSIONS);

        withdraw_fee<Coin>(signer::address_of(account))
    }
}
