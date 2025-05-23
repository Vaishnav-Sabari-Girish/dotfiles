#![cfg(feature = "tokio-support")]

//! Asynchronous named pipes which work with the Tokio runtime and event loop.
//!
//! The Tokio integration allows the named pipe streams and listeners to be notified by the OS kernel whenever they're ready to be read from of written to, instead of spawning threads just to put them in a wait state of blocking on the I/O.
//!
//! Types from this module will *not* work with other async runtimes, such as `async-std` or `smol`, since the Tokio types' methods will panic whenever they're called outside of a Tokio runtime context. Open an issue if you'd like to see other runtimes supported as well.

mod listener;
mod pipeops;
mod stream;

pub use listener::*;
pub use stream::*;

use super::{super::imports, enums};
use pipeops::*;
