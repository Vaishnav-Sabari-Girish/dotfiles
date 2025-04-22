//! Conversions between integer types that check for overflow and underflow
//!
//! The functions that this module exposes attempt to cast from one primitive
//! integer type to another, returning `None` on overflow or underflow.
//!
//! # Examples
//! ```
//! use checked_int_cast::CheckedIntCast;
//!
//! // Returns None if usize has 32 or fewer bits
//! (2u64 << 33).as_usize_checked();
//!
//! // Successful cast
//! assert_eq!(127u8.as_i8_checked(), Some(127i8));
//!
//! // Overflow
//! assert_eq!(255u8.as_i8_checked(), None);
//!
//! // Underflow
//! assert_eq!((-1i8).as_u32_checked(), None);
//! ```

use std::{i8, i16, i32, i64, isize};
use std::{u8, u16, u32, u64, usize};

// The only subtle thing about these implementations is that we need to skip
// the comparison with MAX if we might get overflow in that comparison.
// Conveniently, these are also the cases where the comparison is not
// necessary.
//
// For example, checking the conversion from u32 to usize with the code
//    x > (u32::MAX as usize)
// would work fine with 32-bit or 64-bit usizes. For a 16-bit usize, though,
// u32::MAX would be truncated to 0usize and the comparison would not work
// like we want.
//
// So, to check whether or not the comparison is necesary, we convert both of
// the type's MAXes to f64. Although that conversion won't always be precise,
// it is good enough to tell which type has a larger range. The compiler
// optimizes away this check in release mode.
//

macro_rules! impl_signed_as_unsigned(($fn_name:ident, $from:ident, $to:ident) => (
    #[inline]
    fn $fn_name(self) -> Option<$to> {
        if self < 0 {
            return None;
        }
        if $from::MAX as f64 > $to::MAX as f64 {
            if self > $to::MAX as $from {
                return None;
            }
        }
        return Some(self as $to);
    }
));

macro_rules! impl_signed_as_signed(($fn_name:ident, $from:ident, $to:ident) => (
    #[inline]
    fn $fn_name(self) -> Option<$to> {
        if $from::MAX as f64 > $to::MAX as f64 {
            if self > $to::MAX as $from {
                return None;
            }
            if self < $to::MIN as $from {
                return None;
            }
        }
        return Some(self as $to);
    }
));

macro_rules! impl_unsigned_as_any(($fn_name:ident, $from:ident, $to:ident) => (
    #[inline]
    fn $fn_name(self) -> Option<$to> {
        if $from::MAX as f64 > $to::MAX as f64 {
            if self > $to::MAX as $from {
                return None;
            }
        }
        return Some(self as $to);
    }
));

/// This trait allows a value to be cast to the various primitive integer types.
/// If the conversion overflows or underflows, the functions return `None`.
pub trait CheckedIntCast {
    fn as_isize_checked(self) -> Option<isize>;
    fn as_i8_checked(self) -> Option<i8>;
    fn as_i16_checked(self) -> Option<i16>;
    fn as_i32_checked(self) -> Option<i32>;
    fn as_i64_checked(self) -> Option<i64>;
    fn as_usize_checked(self) -> Option<usize>;
    fn as_u8_checked(self) -> Option<u8>;
    fn as_u16_checked(self) -> Option<u16>;
    fn as_u32_checked(self) -> Option<u32>;
    fn as_u64_checked(self) -> Option<u64>;
}

macro_rules! impl_signed_to_all(($from:ident) => (
    impl CheckedIntCast for $from {
        impl_signed_as_signed!(as_isize_checked, $from, isize);
        impl_signed_as_signed!(as_i8_checked, $from, i8);
        impl_signed_as_signed!(as_i16_checked, $from, i16);
        impl_signed_as_signed!(as_i32_checked, $from, i32);
        impl_signed_as_signed!(as_i64_checked, $from, i64);
        impl_signed_as_unsigned!(as_usize_checked, $from, usize);
        impl_signed_as_unsigned!(as_u8_checked, $from, u8);
        impl_signed_as_unsigned!(as_u16_checked, $from, u16);
        impl_signed_as_unsigned!(as_u32_checked, $from, u32);
        impl_signed_as_unsigned!(as_u64_checked, $from, u64);
    }
));

macro_rules! impl_unsigned_to_all(($from:ident) => (
    impl CheckedIntCast for $from {
        impl_unsigned_as_any!(as_isize_checked, $from, isize);
        impl_unsigned_as_any!(as_i8_checked, $from, i8);
        impl_unsigned_as_any!(as_i16_checked, $from, i16);
        impl_unsigned_as_any!(as_i32_checked, $from, i32);
        impl_unsigned_as_any!(as_i64_checked, $from, i64);
        impl_unsigned_as_any!(as_usize_checked, $from, usize);
        impl_unsigned_as_any!(as_u8_checked, $from, u8);
        impl_unsigned_as_any!(as_u16_checked, $from, u16);
        impl_unsigned_as_any!(as_u32_checked, $from, u32);
        impl_unsigned_as_any!(as_u64_checked, $from, u64);
    }
));

impl_signed_to_all!(isize);
impl_signed_to_all!(i8);
impl_signed_to_all!(i16);
impl_signed_to_all!(i32);
impl_signed_to_all!(i64);

impl_unsigned_to_all!(usize);
impl_unsigned_to_all!(u8);
impl_unsigned_to_all!(u16);
impl_unsigned_to_all!(u32);
impl_unsigned_to_all!(u64);


#[cfg(test)]
mod test {
    use super::CheckedIntCast;

    #[test]
    fn basic() {
        assert_eq!(0u64.as_i8_checked(), Some(0i8));
        assert_eq!((-40i64).as_i8_checked(), Some(-40));
        assert_eq!((-321i64).as_i8_checked(), None);
        assert_eq!(40000000u64.as_u16_checked(), None);
        assert_eq!(40000000u64.as_i32_checked(), Some(40000000i32));
    }

    #[test]
    fn negative_to_unsigned() {
        assert_eq!((-4i8).as_u64_checked(), None);
        assert_eq!((-1i32).as_usize_checked(), None);
        assert_eq!(::std::i32::MIN.as_usize_checked(), None);
        assert_eq!((-3053i64).as_u32_checked(), None);
    }

    #[test]
    fn unsigned_as_unsigned() {
        assert_eq!(256u32.as_u8_checked(), None);
        assert_eq!(255u32.as_u8_checked(), Some(255));
        assert_eq!(256u32.as_u16_checked(), Some(256));
    }
}
