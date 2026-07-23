#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! edition = "2021"
//!
//! [dependencies]
//! inquire = { version = "0.7", features = ["editor"] }
//! ```

use inquire::{Confirm, Editor, Select, Text};
use std::error::Error;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

/// Indent every non-empty line of `text` with `pad`. Empty input becomes a
/// single no-op (`:`) so the generated bash function body is never empty
/// (an empty `{ }` block is a bash syntax error).
fn indent(text: &str, pad: &str) -> String {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return format!("{pad}:");
    }
    trimmed
        .lines()
        .map(|l| {
            if l.trim().is_empty() {
                String::new()
            } else {
                format!("{pad}{l}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Wrap a space-separated list of words in bash array syntax: a b c -> ('a' 'b' 'c')
fn to_array(list: &str) -> String {
    let items: Vec<String> = list
        .split_whitespace()
        .map(|w| format!("'{w}'"))
        .collect();
    if items.is_empty() {
        "()".to_string()
    } else {
        format!("({})", items.join(" "))
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("== Interactive PKGBUILD generator ==\n");

    // --- Core identity ---------------------------------------------------
    let pkgname = Text::new("Package name (pkgname):").prompt()?;

    let underscore_raw = Text::new("Upstream/VCS name (_pkgname), leave empty to skip:")
        .with_help_message("Set this for -git/-bin split packages, e.g. pkgname=foo-git, _pkgname=foo")
        .prompt()?;
    let underscore = if underscore_raw.trim().is_empty() {
        None
    } else {
        Some(underscore_raw.trim().to_string())
    };

    // The variable name to use for cd/source references throughout the PKGBUILD.
    let name_var = if underscore.is_some() { "_pkgname" } else { "pkgname" };

    let pkgver = Text::new("Version (pkgver):").prompt()?;

    let url = Text::new("Repository / homepage URL:").prompt()?;

    let pkgdesc = Text::new("Short description (pkgdesc):")
        .with_default("")
        .prompt()?;

    let license = Text::new("License:").with_default("MIT").prompt()?;

    let arch = Text::new("Architectures (space separated):")
        .with_default("x86_64")
        .prompt()?;

    let depends = Text::new("Runtime dependencies (space separated, empty for none):")
        .with_default("")
        .prompt()?;

    let maintainer = Text::new("Maintainer (Name <email>), leave empty to skip:")
        .with_default("")
        .prompt()?;

    // --- Package type ------------------------------------------------------
    let pkgtype = Select::new("Package type:", vec!["git", "normal", "bin"]).prompt()?;

    let (extra_makedepends, body) = match pkgtype {
        "git" => build_git(&url, name_var)?,
        "normal" => build_normal(&pkgname, name_var, &pkgver)?,
        "bin" => build_bin(&pkgname, name_var, &pkgver)?,
        _ => unreachable!(),
    };

    let makedepends_raw = Text::new("Extra makedepends (space separated, empty for none):")
        .with_default(&extra_makedepends)
        .prompt()?;

    // --- Assemble the PKGBUILD ----------------------------------------------
    let mut out = String::new();
    if !maintainer.trim().is_empty() {
        out.push_str(&format!("# Maintainer: {}\n", maintainer.trim()));
    }
    out.push_str(&format!("pkgname={pkgname}\n"));
    if let Some(u) = &underscore {
        out.push_str(&format!("_pkgname={u}\n"));
    }
    out.push_str(&format!("pkgver={pkgver}\n"));
    out.push_str("pkgrel=1\n");
    out.push_str(&format!("pkgdesc=\"{pkgdesc}\"\n"));
    out.push_str(&format!("arch={}\n", to_array(&arch)));
    out.push_str(&format!("url=\"{url}\"\n"));
    out.push_str(&format!("license={}\n", to_array(&license)));
    out.push_str(&format!("depends={}\n", to_array(&depends)));
    out.push_str(&format!("makedepends={}\n", to_array(&makedepends_raw)));
    out.push('\n');
    out.push_str(&body);

    // --- Write it out --------------------------------------------------------
    let default_dir = format!("./{pkgname}");
    let outdir_raw = Text::new("Output directory (created if missing):")
        .with_default(&default_dir)
        .prompt()?;
    let outdir = PathBuf::from(outdir_raw.trim());
    fs::create_dir_all(&outdir)?;
    let pkgbuild_path = outdir.join("PKGBUILD");
    fs::write(&pkgbuild_path, out)?;
    println!("\nWrote {}", pkgbuild_path.display());

    // --- Auto-generate checksums via updpkgsums -------------------------------
    let run_updpkgsums = Confirm::new("Run `updpkgsums` now to fill in sha256sums?")
        .with_default(true)
        .prompt()?;

    if run_updpkgsums {
        match Command::new("updpkgsums").current_dir(&outdir).status() {
            Ok(status) if status.success() => {
                println!("updpkgsums finished successfully. sha256sums have been filled in.");
            }
            Ok(status) => {
                println!(
                    "updpkgsums exited with status {status}. Check the PKGBUILD and re-run manually if needed."
                );
            }
            Err(e) => {
                println!(
                    "Couldn't run updpkgsums ({e}). It's part of pacman-contrib: \
                     `sudo pacman -S pacman-contrib`. Then run `updpkgsums` inside {}.",
                    outdir.display()
                );
            }
        }
    } else {
        println!(
            "Skipped. Run `updpkgsums` inside {} whenever you're ready.",
            outdir.display()
        );
    }

    println!("\nDone. Review the PKGBUILD, then `makepkg -si` to test it.");
    Ok(())
}

/// git-type package: clone + build from a VCS checkout.
fn build_git(url: &str, name_var: &str) -> Result<(String, String), Box<dyn Error>> {
    let clone_url = Text::new("Git clone URL:")
        .with_default(url)
        .with_help_message("Usually the repo URL, optionally with a .git suffix")
        .prompt()?;

    let build_instr = Editor::new("Build commands (one per line, run inside build()):")
        .with_help_message("e.g. cargo build --release --frozen")
        .prompt()?;

    let package_instr = Editor::new("Install commands (one per line, run inside package()):")
        .with_help_message("e.g. install -Dm755 target/release/foo \"$pkgdir/usr/bin/foo\"")
        .prompt()?;

    let src_dir = if name_var == "_pkgname" { "$_pkgname" } else { "$pkgname" };

    let body = format!(
        "provides=(\"${name_var}\")\n\
         conflicts=(\"${name_var}\")\n\
         source=(\"{src_dir}::git+{clone_url}\")\n\
         sha256sums=('SKIP')\n\
         \n\
         pkgver() {{\n\
         \x20\x20cd \"{src_dir}\"\n\
         \x20\x20printf \"r%s.%s\" \"$(git rev-list --count HEAD)\" \"$(git rev-parse --short HEAD)\"\n\
         }}\n\
         \n\
         build() {{\n\
         \x20\x20cd \"{src_dir}\"\n\
         {}\n\
         }}\n\
         \n\
         package() {{\n\
         \x20\x20cd \"{src_dir}\"\n\
         {}\n\
         }}\n",
        indent(&build_instr, "  "),
        indent(&package_instr, "  "),
    );

    Ok(("git".to_string(), body))
}

/// normal-type package: build from a versioned release tarball.
fn build_normal(pkgname: &str, name_var: &str, pkgver: &str) -> Result<(String, String), Box<dyn Error>> {
    let tarball_pattern = Text::new("Release tarball URL (use $pkgver for the version):")
        .with_help_message("e.g. https://github.com/user/repo/archive/refs/tags/v$pkgver.tar.gz")
        .prompt()?;

    let build_instr = Editor::new("Build commands (one per line, run inside build()):")
        .with_help_message("e.g. make")
        .prompt()?;

    let package_instr = Editor::new("Install commands (one per line, run inside package()):")
        .with_help_message("e.g. make DESTDIR=\"$pkgdir\" install")
        .prompt()?;

    let src_var = if name_var == "_pkgname" { "$_pkgname" } else { "$pkgname" };
    let src_dir = format!("{src_var}-$pkgver");
    let _ = pkgver; // pkgver only appears literally as $pkgver in the generated PKGBUILD
    let _ = pkgname; // superseded by src_var, which already honors _pkgname when set

    let body = format!(
        "source=(\"{src_var}-$pkgver.tar.gz::{tarball_pattern}\")\n\
         sha256sums=('SKIP')\n\
         \n\
         build() {{\n\
         \x20\x20cd \"{src_dir}\"\n\
         {}\n\
         }}\n\
         \n\
         package() {{\n\
         \x20\x20cd \"{src_dir}\"\n\
         {}\n\
         }}\n",
        indent(&build_instr, "  "),
        indent(&package_instr, "  "),
    );

    Ok((String::new(), body))
}

/// bin-type package: fetch a prebuilt release asset and install it directly.
fn build_bin(pkgname: &str, name_var: &str, pkgver: &str) -> Result<(String, String), Box<dyn Error>> {
    let asset_pattern = Text::new("Release asset URL (use $pkgver for the version):")
        .with_help_message("e.g. https://github.com/user/repo/releases/download/v$pkgver/repo-linux-x86_64.tar.gz")
        .prompt()?;

    let is_archive = Confirm::new("Is this asset an archive (tar/zip) rather than a raw binary?")
        .with_default(true)
        .prompt()?;

    let default_bin_name = if name_var == "_pkgname" {
        "$_pkgname".to_string()
    } else {
        "$pkgname".to_string()
    };
    let binary_name = Text::new("Name of the executable to install:")
        .with_default(&default_bin_name)
        .prompt()?;

    let install_path = Text::new("Install path for the binary:")
        .with_default(&format!("/usr/bin/{}", default_bin_name.trim_start_matches('$')))
        .prompt()?;

    let extra_instr = Editor::new(
        "Any extra install commands, e.g. man pages/completions (one per line, empty for none):",
    )
    .prompt()?;

    let src_var = if name_var == "_pkgname" { "$_pkgname" } else { "$pkgname" };
    let _ = pkgname; // superseded by src_var, which already honors _pkgname when set

    let asset_filename = if is_archive {
        format!("{src_var}-$pkgver.tar.gz")
    } else {
        format!("{src_var}-$pkgver")
    };

    let package_body = if is_archive {
        format!(
            "  install -Dm755 \"{binary_name}\" \"$pkgdir{install_path}\"\n{extra}",
            extra = indent(&extra_instr, "  ") ,
        )
    } else {
        format!(
            "  install -Dm755 \"{asset_filename}\" \"$pkgdir{install_path}\"\n{extra}",
            extra = indent(&extra_instr, "  "),
        )
    };
    let _ = pkgver; // pkgver is embedded via $pkgver in the generated strings above

    let body = format!(
        "source=(\"{asset_filename}::{asset_pattern}\")\n\
         sha256sums=('SKIP')\n\
         \n\
         package() {{\n\
         {}\n\
         }}\n",
        package_body,
    );

    Ok((String::new(), body))
}
