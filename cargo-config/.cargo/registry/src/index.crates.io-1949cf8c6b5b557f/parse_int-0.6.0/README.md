# parse_int

[![crates.io](https://img.shields.io/crates/v/parse_int?logo=rust)](https://crates.io/crates/parse_int/)
[![CI pipeline](https://gitlab.com/dns2utf8/parse_int/badges/master/pipeline.svg)](https://gitlab.com/dns2utf8/parse_int/)

Parse &str with common prefixes to integer values:

```rust
use parse_int::parse;

let d = parse::<usize>("42")?;
assert_eq!(42, d);

let d = parse::<isize>("0x42")?;
assert_eq!(66, d);

// you can use underscores for more readable inputs
let d = parse::<isize>("0x42_424_242")?;
assert_eq!(1_111_638_594, d);

let d = parse::<u8>("0o42")?;
assert_eq!(34, d);
#[cfg(feature = "implicit-octal")]
{
    let d = parse::<u8>("042")?;
    assert_eq!(34, d);
}

let d = parse::<u16>("0b0110")?;
assert_eq!(6, d);
```

[Documentation](https://docs.rs/parse_int).

## Enable the "implicit-octal" feature

Specify the crate like this:

```yaml
[dependencies]
parse_int = { version = "0.5", features = ["implicit-octal"] }
```

Then this code will return `Hello, Ok(34)!`:

```rust
use parse_int::parse;
fn main() {
    println!("Hello, {:?}!", parse::<i128>("00042"));
}
```

## License

This work is distributed under the super-Rust quad-license:

[Apache-2.0]/[MIT]/[BSL-1.0]/[CC0-1.0]

This is equivalent to public domain in jurisdictions that allow it (CC0-1.0).
Otherwise it is compatible with the Rust license, plus the option of the
runtime-exception-containing BSL-1. This means that, outside of public domain
jurisdictions, the source must be distributed along with author attribution and
at least one of the licenses; but in binary form no attribution or license
distribution is required.

[Apache-2.0]: https://opensource.org/licenses/Apache-2.0
[MIT]: https://www.opensource.org/licenses/MIT
[BSL-1.0]: https://opensource.org/licenses/BSL-1.0
[CC0-1.0]: https://creativecommons.org/publicdomain/zero/1.0
