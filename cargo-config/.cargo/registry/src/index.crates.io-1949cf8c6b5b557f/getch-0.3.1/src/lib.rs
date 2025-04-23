#[cfg(not(windows))]
extern crate termios;
#[cfg(not(windows))]
use std::io::Read;
#[cfg(windows)]
pub struct Getch{}

#[cfg(not(windows))]
pub enum Getch {
    Termios(termios::Termios),
    None
}

#[cfg(windows)]
extern crate libc;
#[cfg(windows)]
use libc::c_int;
#[cfg(windows)]
extern "C" {
    fn _getch()->c_int;
}

#[cfg(not(windows))]
use termios::{tcsetattr,ICANON,ECHO};

impl Getch {
    #[cfg(windows)]
    pub fn new() -> Getch {
        Getch{}
    }
    #[cfg(not(windows))]
    pub fn new() -> Getch {
        if let Ok(mut termios) = termios::Termios::from_fd(0) {
            let c_lflag = termios.c_lflag;
            termios.c_lflag &= !(ICANON|ECHO);

            if let Ok(()) = tcsetattr(0, termios::TCSADRAIN, &termios) {
                termios.c_lflag = c_lflag;
                return Getch::Termios(termios)
            }
        }
        Getch::None
    }

    #[cfg(windows)]
    pub fn getch(&self) -> Result<u8, std::io::Error> {
        loop {
            unsafe {
                let k= _getch();
                if k==0 {
                    // Ignore next input.
                    _getch();
                } else {
                    return Ok(k as u8)
                }
            }
        }
    }
    #[cfg(not(windows))]
    pub fn getch(&self) -> Result<u8, std::io::Error> {
        let mut r:[u8;1]=[0];
        let mut stdin = std::io::stdin();
        loop {
            if stdin.read(&mut r[..])? == 0 { return Ok(0) }
            else {
                if r[0]==27 {
                    if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                    if r[0] == b'[' || (r[0] >= b'0' && r[0] <= b'9') {
                        if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        // Skip all until we see a letter.
                        while !((r[0] >= b'a' && r[0] <= b'z') || (r[0] >= b'A' && r[0] <= b'Z')) {
                            if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        }
                        if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        return Ok(r[0])
                    } else if r[0] == b'(' || r[0] == b')' || r[0] == b'#' {
                        // skip the next character and return
                        if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        return Ok(r[0])
                    } else {
                        // return the next character
                        if stdin.read(&mut r[..])? == 0 { return Ok(0) }
                        return Ok(r[0])
                    }
                } else {
                    // TODO: accept utf-8
                    return Ok(r[0])
                }
            }
        }
    }
}

impl Drop for Getch {
    #[cfg(not(windows))]
    fn drop(&mut self) {
        if let Getch::Termios(ref mut termios) = *self {
            tcsetattr(0, termios::TCSADRAIN, &termios).unwrap_or(())
        }
    }
    #[cfg(windows)]
    fn drop(&mut self) {
    }
}
