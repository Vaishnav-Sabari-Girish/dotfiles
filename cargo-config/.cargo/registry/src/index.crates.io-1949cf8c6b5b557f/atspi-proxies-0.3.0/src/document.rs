//! # `DBus` interface proxy for: `org.a11y.atspi.Document`
//!
//! This code was generated by `zbus-xmlgen` `2.0.1` from `DBus` introspection data.
//! Source: `Document.xml`.
//!
//! You may prefer to adapt it, instead of using it verbatim.
//!
//! More information can be found in the
//! [Writing a client proxy](https://dbus.pages.freedesktop.org/zbus/client.html)
//! section of the zbus documentation.
//!

use crate::atspi_proxy;

#[atspi_proxy(interface = "org.a11y.atspi.Document", assume_defaults = true)]
trait Document {
	/// GetAttributeValue method
	fn get_attribute_value(&self, attributename: &str) -> zbus::Result<String>;

	/// GetAttributes method
	fn get_attributes(&self) -> zbus::Result<std::collections::HashMap<String, String>>;

	/// GetLocale method
	fn get_locale(&self) -> zbus::Result<String>;

	/// CurrentPageNumber property
	#[dbus_proxy(property)]
	fn current_page_number(&self) -> zbus::Result<i32>;

	/// PageCount property
	#[dbus_proxy(property)]
	fn page_count(&self) -> zbus::Result<i32>;
}
