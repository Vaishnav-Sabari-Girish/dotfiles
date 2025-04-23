extern crate pager;

use std::env;

use pager::Pager;

#[test]
fn nopager() {
    env::set_var("NOPAGER", "");
    let mut pager = Pager::new();
    pager.setup();
    env::remove_var("NOPAGER");
    assert!(!pager.is_on());
}

#[test]
fn skip_on_notty() {
    let mut pager = Pager::new();
    pager.setup();
    assert!(!pager.is_on());
}
