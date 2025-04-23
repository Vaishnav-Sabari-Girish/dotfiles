## Pager - long output best friend

[![Build Status](https://gitlab.com/imp/pager-rs/badges/master/build.svg)](https://gitlab.com/imp/pager-rs/pipelines)
[![Crates.io](https://img.shields.io/crates/v/pager.svg)](https://crates.io/crates/pager)
[![Docs.rs](https://docs.rs/pager/badge.svg)](https://docs.rs/pager)

Does all the magic to have you potentially long output piped through the
external pager. Similar to what `git` does for its output.

# Quick Start

```rust
extern crate pager;

use pager::Pager;

fn main() {
    Pager::new().setup();
    // The rest of your program goes here
}
```

Under the hood this forks the current process, connects child' stdout
to parent's stdin, and then replaces the parent with the pager of choice
(environment variable PAGER). The child just continues as normal. If PAGER
environment variable is not present `Pager` probes current PATH for `more`.
If found it is used as a default pager.

You can control pager to a limited degree. For example you can change the
environment variable used for finding pager executable.

```rust
extern crate pager;

use pager::Pager;

fn main() {
    Pager::with_env("MY_PAGER").setup();
    // The rest of your program goes here
}
```
Also you can set alternative default (fallback) pager to be used instead of
`more`. PAGER environment variable (if set) will still have precedence.

```rust
extern crate pager;

use pager::Pager;

fn main() {
    Pager::with_default_pager("pager").setup();
    // The rest of your program goes here
}
```


If no suitable pager found `setup()` does nothing and your executable keeps
running as usual. `Pager` cleans after itself and doesn't leak resources in
case of setup failure.

Alternatively you can specify directly the desired pager command, exactly
as it would appear in PAGER environment variable. This is useful if you
need some specific pager and/or flags (like "less -r") and would like to
avoid forcing your consumers into modifying their existing PAGER
configuration just for your application.

```rust
extern crate pager;
use pager::Pager;
fn main() {
    Pager::with_pager("less -r").setup();
    // The rest of your program goes here
}
```

Sometimes you may want to bypass pager if the output of you executable
is not a `tty`. If this case you may use `.skip_on_notty()` to get the
desirable effect.

```rust
extern crate pager;
use pager::Pager;
fn main() {
    Pager::new().skip_on_notty().setup();
    // The rest of your program goes here
}
```

If you need to disable pager altogether set environment variable `NOPAGER`
and Pager::setup() will skip initialization. The host application will continue
as normal. Pager::is_on() will reflect the fact that no Pager is active.
