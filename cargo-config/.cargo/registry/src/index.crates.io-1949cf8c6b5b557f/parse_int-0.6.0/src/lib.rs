#![deny(warnings)]
//!
//! Parse &str with common prefixes to integer values
//!
//! ```
//! # use std::error::Error;
//! # fn main() -> Result<(), Box<dyn Error>> {
//! use parse_int::parse;
//!
//! let d = parse::<usize>("42")?;
//! assert_eq!(42, d);
//!
//! let d = parse::<isize>("0x42")?;
//! assert_eq!(66, d);
//!
//! // you can use underscores for more readable inputs
//! let d = parse::<isize>("0x42_424_242")?;
//! assert_eq!(1_111_638_594, d);
//!
//! // octal explicit
//! let d = parse::<u8>("0o42")?;
//! assert_eq!(34, d);
//!
//! ##[cfg(feature = "implicit-octal")]
//! {
//!     let d = parse::<i8>("042")?;
//!     assert_eq!(34, d);
//! }
//!
//! let d = parse::<u16>("0b0110")?;
//! assert_eq!(6, d);
//! #
//! #     Ok(())
//! # }
//! ```

use num_traits::Num;

/// Parse &str with common prefixes to integer values
///
/// ```
/// # use std::error::Error;
/// # fn main() -> Result<(), Box<dyn Error>> {
/// use parse_int::parse;
///
/// // decimal
/// let d = parse::<usize>("42")?;
/// assert_eq!(42, d);
///
/// // hex
/// let d = parse::<isize>("0x42")?;
/// assert_eq!(66, d);
///
/// // you can use underscores for more readable inputs
/// let d = parse::<isize>("0x42_424_242")?;
/// assert_eq!(1_111_638_594, d);
///
/// // octal explicit
/// let d = parse::<u8>("0o42")?;
/// assert_eq!(34, d);
///
/// ##[cfg(feature = "implicit-octal")]
/// {
///     let d = parse::<i8>("042")?;
///     assert_eq!(34, d);
/// }
///
/// // binary
/// let d = parse::<u16>("0b0110")?;
/// assert_eq!(6, d);
/// #
/// #     Ok(())
/// # }
/// ```
#[inline]
pub fn parse<T: Num>(input: &str) -> Result<T, T::FromStrRadixErr> {
    let input = input.trim();

    // invalid start
    if input.starts_with("_") {
        /* With rust 1.55 the return type is stable but we can not construct it yet

        let kind = ::core::num::IntErrorKind::InvalidDigit;
        //let pie = ::core::num::ParseIntError {
        let pie = <<T as num_traits::Num>::FromStrRadixErr as Trait>::A {
            kind
        };
        return Err(pie);
        */
        return T::from_str_radix("XYZ", 2);
    }

    // hex
    if input.starts_with("0x") {
        return parse_with_base(&input[2..], 16);
    }

    // binary
    if input.starts_with("0b") {
        return parse_with_base(&input[2..], 2);
    }

    // octal
    if input.starts_with("0o") {
        return parse_with_base(&input[2..], 8);
    }
    #[cfg(feature = "implicit-octal")]
    {
        if input.starts_with("0") {
            return if input == "0" {
                Ok(T::zero())
            } else {
                parse_with_base(&input[1..], 8)
            };
        }
    }

    // decimal
    parse_with_base(&input, 10)
}

#[inline]
fn parse_with_base<T: Num>(input: &str, base: u32) -> Result<T, T::FromStrRadixErr> {
    let input = input.chars().filter(|&c| c != '_').collect::<String>();
    T::from_str_radix(&input, base)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn turbofish_usize_dec() {
        let s = "42";

        let u = parse::<usize>(s).unwrap();

        assert_eq!(42, u);
    }

    #[test]
    fn deduct_usize_dec() {
        let s = "42";

        let u = parse(s).unwrap();

        assert_eq!(42usize, u);
    }

    macro_rules! int_parse {
        ($type:ident, $s:literal, $e:literal) => {
            #[test]
            fn $type() {
                let u: Result<$type, _> = crate::parse($s);
                assert_eq!(Ok($e), u);
            }
        };
    }

    macro_rules! int_parse_err {
        ($type:ident, $s:literal) => {
            int_parse_err!($type, $s, err);
        };
        ($type:ident, $s:literal, $opt:ident) => {
            mod $opt {
                #[test]
                fn $type() {
                    let u: Result<$type, _> = crate::parse($s);
                    assert!(u.is_err(), "expected Err(_), got = {:?}", u);
                }
            }
        };
    }

    mod decimal {
        int_parse!(usize, "42", 42);
        int_parse!(isize, "42", 42);
        int_parse!(u8, "42", 42);
        int_parse!(i8, "42", 42);
        int_parse!(u16, "42", 42);
        int_parse!(i16, "42", 42);
        int_parse!(u32, "42", 42);
        int_parse!(i32, "42", 42);
        int_parse!(u64, "42", 42);
        int_parse!(i64, "42", 42);
        int_parse!(u128, "42", 42);
        int_parse!(i128, "42", 42);
    }

    mod decimal_negative {
        int_parse!(isize, "-42", -42);
        int_parse!(i8, "-42", -42);
    }

    mod hexadecimal {
        int_parse!(usize, "0x42", 66);
        int_parse!(isize, "0x42", 66);
        int_parse!(u8, "0x42", 66);
        int_parse!(i8, "0x42", 66);
        int_parse!(u16, "0x42", 66);
        int_parse!(i16, "0x42", 66);
        int_parse!(u32, "0x42", 66);
        int_parse!(i32, "0x42", 66);
        int_parse!(u64, "0x42", 66);
        int_parse!(i64, "0x42", 66);
        int_parse!(u128, "0x42", 66);
        int_parse!(i128, "0x42", 66);
    }

    mod octal_explicit {
        int_parse!(usize, "0o42", 34);
        int_parse!(isize, "0o42", 34);
        int_parse!(u8, "0o42", 34);
        int_parse!(i8, "0o42", 34);
        int_parse!(u16, "0o42", 34);
        int_parse!(i16, "0o42", 34);
        int_parse!(u32, "0o42", 34);
        int_parse!(i32, "0o42", 34);
        int_parse!(u64, "0o42", 34);
        int_parse!(i64, "0o42", 34);
        int_parse!(u128, "0o42", 34);
        int_parse!(i128, "0o42", 34);
    }

    #[cfg(feature = "implicit-octal")]
    mod octal_implicit {
        use super::*;
        int_parse!(usize, "042", 34);
        int_parse!(isize, "042", 34);
        int_parse!(u8, "042", 34);
        int_parse!(i8, "042", 34);
        int_parse!(u16, "042", 34);
        int_parse!(i16, "042", 34);
        int_parse!(u32, "042", 34);
        int_parse!(i32, "042", 34);
        int_parse!(u64, "042", 34);
        int_parse!(i64, "042", 34);
        int_parse!(u128, "042", 34);
        int_parse!(i128, "042", 34);

        #[test]
        fn issue_nr_0() {
            let s = "0";

            assert_eq!(0, parse::<usize>(s).unwrap());
            assert_eq!(0, parse::<isize>(s).unwrap());
            assert_eq!(0, parse::<i8>(s).unwrap());
            assert_eq!(0, parse::<u8>(s).unwrap());
            assert_eq!(0, parse::<i16>(s).unwrap());
            assert_eq!(0, parse::<u16>(s).unwrap());
            assert_eq!(0, parse::<i32>(s).unwrap());
            assert_eq!(0, parse::<u32>(s).unwrap());
            assert_eq!(0, parse::<i64>(s).unwrap());
            assert_eq!(0, parse::<u64>(s).unwrap());
            assert_eq!(0, parse::<i128>(s).unwrap());
            assert_eq!(0, parse::<u128>(s).unwrap());
        }
    }
    #[cfg(not(feature = "implicit-octal"))]
    mod octal_implicit_disabled {
        use super::*;
        #[test]
        /// maybe this will change in the future
        fn no_implicit_is_int() {
            let s = "042";

            let u = parse::<usize>(s);
            assert_eq!(Ok(42), u, "{:?}", u);
        }
    }

    mod binary {
        int_parse!(usize, "0b0110", 6);
        int_parse!(isize, "0b0110", 6);
        int_parse!(u8, "0b0110", 6);
        int_parse!(i8, "0b0110", 6);
        int_parse!(u16, "0b0110", 6);
        int_parse!(i16, "0b0110", 6);
        int_parse!(u32, "0b0110", 6);
        int_parse!(i32, "0b0110", 6);
        int_parse!(u64, "0b0110", 6);
        int_parse!(i64, "0b0110", 6);
        int_parse!(u128, "0b0110", 6);
        int_parse!(i128, "0b0110", 6);
    }

    mod binary_negative {
        int_parse_err!(i8, "0b1000_0000");
        int_parse!(i8, "0b-0111_1111", -127);
    }

    mod underscore {
        int_parse!(usize, "0b0110_0110", 102);
        int_parse!(isize, "0x0110_0110", 17_826_064);
        int_parse!(u64, "0o0110_0110", 294_984);
        int_parse!(u128, "1_100_110", 1_100_110);

        #[cfg(feature = "implicit-octal")]
        mod implicit_octal {
            int_parse!(i128, "0110_0110", 294_984);
        }
        #[cfg(not(feature = "implicit-octal"))]
        mod implicit_octal {
            int_parse!(i128, "0110_0110", 1_100_110);
        }
    }

    mod underscore_in_prefix {
        #[test]
        fn invalid_underscore_in_prefix() {
            let r = crate::parse::<isize>("_4");
            println!("{:?}", r);
            assert!(r.is_err());
        }
        int_parse_err!(isize, "0_x_4", hex);
        int_parse_err!(isize, "_4", decimal);
        int_parse_err!(isize, "0_o_4", octal);
        int_parse_err!(isize, "0_b_1", binary);
    }
}
