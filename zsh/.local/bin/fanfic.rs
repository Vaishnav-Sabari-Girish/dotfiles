#!/usr/bin/env rust-script
//! fanfic — download fanfics via fichub-cli and open them with bookokrat
//!
//! ```cargo
//! [dependencies]
//! colored = "2"
//! inquire = "0.7"
//! zip = "2"
//! regex = "1"
//! ```

use colored::Colorize;
use inquire::Select;
use regex::Regex;
use std::collections::HashSet;
use std::env;
use std::fs;
use std::io::Read;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::SystemTime;
use zip::ZipArchive;

const FANFIC_DIR_NAME: &str = "fanfic";
const READER: &str = "bookokrat";
const DOWNLOADER: &str = "fichub_cli";

fn fanfic_dir() -> PathBuf {
    dirs_next_home().join(FANFIC_DIR_NAME)
}

fn dirs_next_home() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .expect("$HOME is not set")
}

fn err(msg: &str) {
    eprintln!("{} {}", "error:".red().bold(), msg);
}

fn warn(msg: &str) {
    eprintln!("{} {}", "warning:".yellow().bold(), msg);
}

fn ok(msg: &str) {
    println!("{}", msg.green());
}

fn usage() {
    println!(
        "\
Usage:
  fanfic i <url>   Download fanfic as EPUB to ~/fanfic/ and open with bookokrat
  fanfic           Open interactive picker of downloaded fanfics in ~/fanfic/

Examples:
  fanfic i \"https://archiveofourown.org/works/12345\"
  fanfic"
    );
}

fn command_exists(cmd: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v '{}'", cmd.replace('\'', "'\\''")))
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn require_cmd(cmd: &str) {
    if command_exists(cmd) {
        return;
    }
    err(&format!("'{cmd}' is not installed or not in PATH."));
    match cmd {
        "fichub_cli" => eprintln!("  Install with: pip install -U fichub-cli"),
        "bookokrat" => {
            eprintln!("  Install from: https://github.com/bugzmanov/bookokrat");
            eprintln!("  (Homebrew: brew install bookokrat, or cargo install bookokrat)");
        }
        _ => {}
    }
    std::process::exit(1);
}

fn ensure_dir(dir: &Path) {
    if !dir.is_dir() {
        if let Err(e) = fs::create_dir_all(dir) {
            err(&format!("Could not create directory {}: {e}", dir.display()));
            std::process::exit(1);
        }
        ok(&format!("Created {}", dir.display()));
    }
}

fn list_epubs(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    fn walk(dir: &Path, out: &mut Vec<PathBuf>) {
        let Ok(entries) = fs::read_dir(dir) else { return };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                walk(&path, out);
            } else if path
                .extension()
                .and_then(|e| e.to_str())
                .map(|e| e.eq_ignore_ascii_case("epub"))
                .unwrap_or(false)
            {
                out.push(path);
            }
        }
    }
    walk(dir, &mut out);
    out
}

fn find_newest_epub(dir: &Path) -> Option<PathBuf> {
    list_epubs(dir)
        .into_iter()
        .filter_map(|p| {
            let modified = fs::metadata(&p).ok()?.modified().ok()?;
            Some((modified, p))
        })
        .max_by_key(|(t, _)| *t)
        .map(|(_, p)| p)
}

fn epub_title(path: &Path) -> String {
    // Try to read real title from the OPF
    if let Ok(file) = fs::File::open(path) {
        if let Ok(mut archive) = ZipArchive::new(file) {
            // find the .opf
            let opf_name = (0..archive.len()).find_map(|i| {
                let name = archive.by_index(i).ok()?.name().to_string();
                if name.ends_with(".opf") {
                    Some(name)
                } else {
                    None
                }
            });

            if let Some(opf_name) = opf_name {
                if let Ok(mut opf) = archive.by_name(&opf_name) {
                    let mut content = String::new();
                    if opf.read_to_string(&mut content).is_ok() {
                        // match <dc:title>...</dc:title>
                        let re = Regex::new(r"<dc:title[^>]*>([^<]+)</dc:title>").unwrap();
                        if let Some(caps) = re.captures(&content) {
                            let title = caps[1].trim();
                            if !title.is_empty() {
                                return title.to_string();
                            }
                        }
                    }
                }
            }
        }
    }

    // Fallback: prettify the filename
    path.file_stem()
        .map(|s| {
            let s = s.to_string_lossy().replace('_', " ");
            // strip trailing " - id" if present
            s.rsplit_once(" - ")
                .map(|(title, _)| title.to_string())
                .unwrap_or(s)
        })
        .unwrap_or_else(|| path.display().to_string())
}

fn download_and_open(url: &str) {
    if url.is_empty() {
        err("No URL provided.");
        usage();
        std::process::exit(1);
    }
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        err("URL must start with http:// or https://");
        std::process::exit(1);
    }

    require_cmd(DOWNLOADER);
    require_cmd(READER);

    let dir = fanfic_dir();
    ensure_dir(&dir);

    let before: HashSet<PathBuf> = list_epubs(&dir).into_iter().collect();

    ok(&format!("Downloading to {} ...", dir.display()));
    println!("  URL: {url}");

    let status = Command::new(DOWNLOADER)
        .args(["-u", url, "-o"])
        .arg(&dir)
        .args(["--format", "epub", "--force"])
        .status();

    match status {
        Ok(s) if s.success() => {}
        Ok(s) => {
            err(&format!(
                "fichub_cli failed (exit code {}).",
                s.code().unwrap_or(-1)
            ));
            if Path::new("./err.log").is_file() {
                warn("Check err.log in the current directory for details.");
            }
            std::process::exit(s.code().unwrap_or(1));
        }
        Err(e) => {
            err(&format!("failed to run {DOWNLOADER}: {e}"));
            std::process::exit(1);
        }
    }

    let after: HashSet<PathBuf> = list_epubs(&dir).into_iter().collect();
    let mut new_files: Vec<PathBuf> = after.difference(&before).cloned().collect();

    let epub = if !new_files.is_empty() {
        new_files.sort_by_key(|p| {
            fs::metadata(p)
                .and_then(|m| m.modified())
                .unwrap_or(SystemTime::UNIX_EPOCH)
        });
        new_files.pop().unwrap()
    } else {
        warn(&format!(
            "Could not detect a brand-new file. Using most recent EPUB in {}",
            dir.display()
        ));
        match find_newest_epub(&dir) {
            Some(p) => p,
            None => {
                err(&format!(
                    "Download appeared to succeed but no EPUB was found in {}",
                    dir.display()
                ));
                err("Check that fichub_cli supports this site and try again.");
                std::process::exit(1);
            }
        }
    };

    ok(&format!(
        "Downloaded: {}",
        epub.file_name().unwrap_or_default().to_string_lossy()
    ));
    println!("Opening with {READER} ...");

    let e = Command::new(READER).arg(&epub).exec();
    err(&format!("failed to exec {READER}: {e}"));
    std::process::exit(1);
}

fn browse_and_open() {
    require_cmd(READER);

    let dir = fanfic_dir();
    ensure_dir(&dir);

    let epubs = list_epubs(&dir);
    if epubs.is_empty() {
        err(&format!("No EPUB files found in {}", dir.display()));
        eprintln!("  Download one first with: fanfic i <url>");
        std::process::exit(1);
    }

    // (display title, full path)
    let mut items: Vec<(String, PathBuf)> = epubs
        .into_iter()
        .map(|p| (epub_title(&p), p))
        .collect();

    // sort by title
    items.sort_by(|a, b| a.0.to_lowercase().cmp(&b.0.to_lowercase()));

    let titles: Vec<String> = items.iter().map(|(t, _)| t.clone()).collect();

    let selected_title = match Select::new("Select a fanfic:", titles)
        .with_page_size(15)
        .with_vim_mode(true)
        .without_help_message()
        .prompt()
    {
        Ok(choice) => choice,
        Err(_) => {
            println!("Cancelled.");
            std::process::exit(0);
        }
    };

    let fullpath = items
        .into_iter()
        .find(|(title, _)| title == &selected_title)
        .map(|(_, path)| path)
        .expect("selected title should always match an item");

    if !fullpath.is_file() {
        err(&format!(
            "Selected file no longer exists: {}",
            fullpath.display()
        ));
        std::process::exit(1);
    }

    ok(&format!("Opening: {selected_title}"));
    let e = Command::new(READER).arg(&fullpath).exec();
    err(&format!("failed to exec {READER}: {e}"));
    std::process::exit(1);
}

fn main() {
    let mut args: Vec<String> = env::args().skip(1).collect();

    match args.first().map(String::as_str) {
        Some("i") | Some("install") | Some("download") | Some("get") => {
            args.remove(0);
            let url = args.first().map(String::as_str).unwrap_or("");
            download_and_open(url);
        }
        Some("-h") | Some("--help") | Some("help") => {
            usage();
        }
        None => {
            browse_and_open();
        }
        Some(other) => {
            err(&format!("Unknown command: {other}"));
            usage();
            std::process::exit(1);
        }
    }
}
