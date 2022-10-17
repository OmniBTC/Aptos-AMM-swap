// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
#[test_only]
module swap::controller_tests {
    use std::signer;
    use swap::controller;
    use swap::implements;

    #[test(account = @swap)]
    #[expected_failure(abort_code = 308)]
    fun test_pause_should_fail_without_init(
        account: &signer
    ) {
        controller::pause(account)
    }

    #[test(account = @swap)]
    #[expected_failure(abort_code = 308)]
    fun test_resume_should_fail_without_init(
        account: &signer
    ) {
        controller::resume(account)
    }

    #[test]
    #[expected_failure(abort_code = 308)]
    fun test_check_emergency_fail_without_init() {
        assert!(!controller::is_emergency(), 1);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    fun test_pause_should_ok(
        swap: &signer,
        controller: &signer,
        beneficiary: address
    ) {
        let controller_address = signer::address_of(controller);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary);

        assert!(!controller::is_emergency(), 1);
        controller::pause(controller);
        assert!(controller::is_emergency(), 2);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    #[expected_failure(abort_code = 201)]
    fun test_pause_already_pause_should_fail(
        swap: &signer,
        controller: &signer,
        beneficiary: address
    ) {
        let controller_address = signer::address_of(controller);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary);

        assert!(!controller::is_emergency(), 1);
        controller::pause(controller);
        assert!(controller::is_emergency(), 2);

        controller::pause(controller);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    #[expected_failure(abort_code = 200)]
    fun test_not_controller_pause_should_fail(
        swap: &signer,
        controller: &signer,
        beneficiary: &signer
    ) {
        let controller_address = signer::address_of(controller);
        let beneficiary_address = signer::address_of(beneficiary);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary_address);

        assert!(!controller::is_emergency(), 1);
        controller::pause(beneficiary);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    fun test_resume_should_ok(
        swap: &signer,
        controller: &signer,
        beneficiary: address
    ) {
        let controller_address = signer::address_of(controller);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary);

        assert!(!controller::is_emergency(), 1);
        controller::pause(controller);
        assert!(controller::is_emergency(), 2);
        controller::resume(controller);
        assert!(!controller::is_emergency(), 3);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    #[expected_failure(abort_code = 202)]
    fun test_resume_already_resume_should_fail(
        swap: &signer,
        controller: &signer,
        beneficiary: address
    ) {
        let controller_address = signer::address_of(controller);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary);

        assert!(!controller::is_emergency(), 1);
        controller::pause(controller);
        assert!(controller::is_emergency(), 2);
        controller::resume(controller);
        assert!(!controller::is_emergency(), 3);

        controller::resume(controller);
    }

    #[test(swap = @swap, controller = @0x123, beneficiary = @0x234)]
    #[expected_failure(abort_code = 200)]
    fun test_not_controller_resume_should_fail(
        swap: &signer,
        controller: &signer,
        beneficiary: &signer
    ) {
        let controller_address = signer::address_of(controller);
        let beneficiary_address = signer::address_of(beneficiary);

        implements::initialize_swap_for_test(swap, controller_address, beneficiary_address);

        assert!(!controller::is_emergency(), 1);
        controller::pause(controller);
        assert!(controller::is_emergency(), 2);

        controller::resume(beneficiary);
    }
}
