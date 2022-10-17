// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
#[test_only]
module swap::math_tests {
    const MAX_u64: u64 = 18446744073709551615;

    #[test]
    fun test_mul_div() {
        let a = swap::math::mul_div(MAX_u64, MAX_u64, MAX_u64);
        assert!(a == MAX_u64, 0);

        a = swap::math::mul_div(100, 20, 100);
        assert!(a == 20, 1);
    }

    #[test, expected_failure(abort_code = 500)]
    fun test_div_zero() {
        swap::math::mul_div(MAX_u64, MAX_u64, 0);
    }

    #[test, expected_failure(abort_code = 501)]
    fun test_mul_div_overflow() {
        swap::math::mul_div(MAX_u64, MAX_u64, 1);
    }

    #[test]
    fun test_sqrt() {
        let s = swap::math::sqrt(9);
        assert!(s == 3, 0);

        s = swap::math::sqrt(0);
        assert!(s == 0, 1);

        s = swap::math::sqrt(1);
        assert!(s == 1, 2);

        s = swap::math::sqrt(2);
        assert!(s == 1, 3);

        s = swap::math::sqrt(3);
        assert!(s == 1, 4);

        s = swap::math::sqrt(18446744073709551615);
        assert!(s == 4294967295, 5);
    }

}
