//! Provides a clipboard abstraction to access the target system's clipboard.

use copypasta::{ClipboardContext, ClipboardProvider};
use dioxus::prelude::*;

#[derive(Debug, PartialEq, Clone)]
pub enum ClipboardError {
    FailedToRead,
    FailedToSet,
    NotAvailable,
}

/// Handle to access the ClipboardContext.
#[derive(Clone, Copy, PartialEq)]
pub struct UseClipboard {
    clipboard: Signal<Option<ClipboardContext>>,
}

impl UseClipboard {
    // Read from the clipboard
    pub fn get(&mut self) -> Result<String, ClipboardError> {
        self.clipboard
            .write()
            .as_mut()
            .ok_or(ClipboardError::NotAvailable)?
            .get_contents()
            .map_err(|_| ClipboardError::FailedToRead)
    }

    // Write to the clipboard
    pub fn set(&mut self, contents: String) -> Result<(), ClipboardError> {
        self.clipboard
            .write()
            .as_mut()
            .ok_or(ClipboardError::NotAvailable)?
            .set_contents(contents)
            .map_err(|_| ClipboardError::FailedToSet)
    }
}

/// Access the clipboard.
///
/// # Examples
///
/// ```ignore
/// use dioxus_sdk::clipboard::use_clipboard;
///
/// // Get a handle to the clipboard
/// let mut clipboard = use_clipboard();
///
/// // Read the clipboard content
/// if let Ok(content) = clipboard.get() {
///     println!("{}", content);
/// }
///
/// // Write to the clipboard
/// clipboard.set("Hello, Dioxus!".to_string());;
///  
/// ```
pub fn use_clipboard() -> UseClipboard {
    let clipboard = match try_consume_context() {
        Some(rt) => rt,
        None => {
            let clipboard_signal =
                Signal::new_in_scope(ClipboardContext::new().ok(), ScopeId::ROOT);
            provide_root_context(clipboard_signal)
        }
    };
    UseClipboard { clipboard }
}
