//! # `DBus` interface proxy for: `org.a11y.atspi.Hypertext`
//!
//! This code was generated by `zbus-xmlgen` `2.0.1` from `DBus` introspection data.
//! Source: `Hypertext.xml`.
//!
//! You may prefer to adapt it, instead of using it verbatim.
//!
//! More information can be found in the
//! [Writing a client proxy](https://dbus.pages.freedesktop.org/zbus/client.html)
//! section of the zbus documentation.
//!

use crate::atspi_proxy;
use crate::common::Accessible;

#[atspi_proxy(interface = "org.a11y.atspi.Hypertext", assume_defaults = true)]
trait Hypertext {
	/// GetLink method
	fn get_link(&self, link_index: i32) -> zbus::Result<Accessible>;

	/// GetLinkIndex method
	fn get_link_index(&self, character_index: i32) -> zbus::Result<i32>;

	/// GetNLinks method
	fn get_nlinks(&self) -> zbus::Result<i32>;
}
