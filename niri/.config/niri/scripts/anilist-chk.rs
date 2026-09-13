#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! reqwest = { version = "*", features = ["blocking", "json"] }
//! serde = { version = "*", features = ["derive"] }
//! serde_json = "*"
//! open = "*"
//! dirs = "*"
//! ```

use std::collections::HashMap;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::Command;

use serde::{Deserialize, Serialize};
use serde_json::Value;

const API_URL: &str = "https://graphql.anilist.co";
const AUTH_URL: &str = "https://anilist.co/api/v2/oauth/authorize";
const PIN_REDIRECT: &str = "https://anilist.co/api/v2/oauth/pin";

#[derive(Debug, Serialize, Deserialize, Default)]
struct Config {
    client_id: String,
    token: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct State {
    /// media_id -> last known available episode count
    available: HashMap<u64, u32>,
}

#[derive(Debug)]
struct AnimeEntry {
    id: u64,
    title: String,
    progress: u32,
    available: u32,
}

fn config_dir() -> PathBuf {
    dirs::config_dir()
        .expect("Could not find config directory")
        .join("anilist-checker")
}

fn ensure_config_dir() {
    let dir = config_dir();
    if !dir.exists() {
        fs::create_dir_all(&dir).expect("Failed to create config directory");
    }
}

fn load_config() -> Option<Config> {
    let path = config_dir().join("config.json");
    if !path.exists() {
        return None;
    }
    let data = fs::read_to_string(&path).ok()?;
    serde_json::from_str(&data).ok()
}

fn save_config(cfg: &Config) {
    ensure_config_dir();
    let path = config_dir().join("config.json");
    let data = serde_json::to_string_pretty(cfg).unwrap();
    fs::write(&path, data).expect("Failed to write config");
}

fn load_state() -> State {
    let path = config_dir().join("state.json");
    if !path.exists() {
        return State::default();
    }
    let data = fs::read_to_string(&path).unwrap_or_default();
    serde_json::from_str(&data).unwrap_or_default()
}

fn save_state(state: &State) {
    ensure_config_dir();
    let path = config_dir().join("state.json");
    let data = serde_json::to_string_pretty(state).unwrap();
    fs::write(&path, data).expect("Failed to write state");
}

fn prompt(msg: &str) -> String {
    print!("{}", msg);
    io::stdout().flush().unwrap();
    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();
    input.trim().to_string()
}

fn setup_auth() -> Config {
    println!("=== AniList Checker – First-time setup ===\n");
    println!("1. A browser window will open to AniList Developer Settings.");
    println!("2. Click \"Create New Client\".");
    println!("3. Name it anything (e.g. \"Episode Checker\").");
    println!("4. Set Redirect URL exactly to:");
    println!("   {}", PIN_REDIRECT);
    println!("5. Save and copy the Client ID.\n");

    let _ = open::that("https://anilist.co/settings/developer");

    let client_id = prompt("Paste your Client ID here: ");

    let auth_link = format!(
        "{}?client_id={}&response_type=token",
        AUTH_URL, client_id
    );

    println!("\nOpening authorization page...");
    let _ = open::that(&auth_link);

    println!("\nAfter approving, you will see a page with your access token.");
    println!("Copy the whole token (it is a long JWT string).\n");

    let token = prompt("Paste the access token here: ");

    let cfg = Config {
        client_id,
        token: token.trim().to_string(),
    };
    save_config(&cfg);
    println!("\nToken saved securely to ~/.config/anilist-checker/config.json");
    cfg
}

fn graphql(token: &str, query: &str, variables: Value) -> Result<Value, String> {
    let client = reqwest::blocking::Client::new();
    let body = serde_json::json!({
        "query": query,
        "variables": variables
    });

    let resp = client
        .post(API_URL)
        .header("Authorization", format!("Bearer {}", token))
        .header("Content-Type", "application/json")
        .header("Accept", "application/json")
        .json(&body)
        .send()
        .map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        return Err(format!("HTTP {}", resp.status()));
    }

    let json: Value = resp.json().map_err(|e| e.to_string())?;
    if let Some(errors) = json.get("errors") {
        return Err(format!("GraphQL errors: {}", errors));
    }
    Ok(json["data"].clone())
}

fn get_user_id(token: &str) -> Result<u64, String> {
    let query = r#"
        query {
            Viewer {
                id
                name
            }
        }
    "#;
    let data = graphql(token, query, Value::Null)?;
    let id = data["Viewer"]["id"]
        .as_u64()
        .ok_or("Could not get user id")?;
    let name = data["Viewer"]["name"].as_str().unwrap_or("?");
    println!("Logged in as: {} (id {})\n", name, id);
    Ok(id)
}

fn fetch_watching(token: &str, user_id: u64) -> Result<Vec<AnimeEntry>, String> {
    let query = r#"
        query ($userId: Int) {
            MediaListCollection(userId: $userId, type: ANIME, status: CURRENT) {
                lists {
                    entries {
                        progress
                        media {
                            id
                            title {
                                userPreferred
                                romaji
                                english
                            }
                            episodes
                            nextAiringEpisode {
                                episode
                            }
                        }
                    }
                }
            }
        }
    "#;

    let variables = serde_json::json!({ "userId": user_id });
    let data = graphql(token, query, variables)?;

    let mut results = Vec::new();
    let lists = data["MediaListCollection"]["lists"]
        .as_array()
        .cloned()
        .unwrap_or_default();

    for list in lists {
        let entries = list["entries"].as_array().cloned().unwrap_or_default();
        for entry in entries {
            let progress = entry["progress"].as_u64().unwrap_or(0) as u32;
            let media = &entry["media"];
            let id = media["id"].as_u64().unwrap_or(0);

            let title = media["title"]["userPreferred"]
                .as_str()
                .or_else(|| media["title"]["english"].as_str())
                .or_else(|| media["title"]["romaji"].as_str())
                .unwrap_or("Unknown")
                .to_string();

            let available = if let Some(next) = media["nextAiringEpisode"].as_object() {
                next["episode"].as_u64().unwrap_or(1).saturating_sub(1) as u32
            } else if let Some(eps) = media["episodes"].as_u64() {
                eps as u32
            } else {
                progress
            };

            results.push(AnimeEntry {
                id,
                title,
                progress,
                available,
            });
        }
    }
    Ok(results)
}

fn print_table(headers: &[&str], rows: &[Vec<String>]) {
    if rows.is_empty() {
        return;
    }

    let mut widths: Vec<usize> = headers.iter().map(|h| h.len()).collect();
    for row in rows {
        for (i, cell) in row.iter().enumerate() {
            if i < widths.len() {
                widths[i] = widths[i].max(cell.len());
            }
        }
    }

    let header_line: String = headers
        .iter()
        .enumerate()
        .map(|(i, h)| format!("{:width$}", h, width = widths[i]))
        .collect::<Vec<_>>()
        .join("  ");
    println!("{}", header_line);

    let sep: String = widths
        .iter()
        .map(|w| "─".repeat(*w))
        .collect::<Vec<_>>()
        .join("──");
    println!("{}", sep);

    for row in rows {
        let line: String = row
            .iter()
            .enumerate()
            .map(|(i, cell)| format!("{:width$}", cell, width = widths[i]))
            .collect::<Vec<_>>()
            .join("  ");
        println!("{}", line);
    }
}

fn show_zenity_dialog(
    newly_released: &[(String, u32, u32)],
    behind: &[(String, u32, u32)],
) {
    // Prefer a list dialog when we have data
    if newly_released.is_empty() && behind.is_empty() {
        let _ = Command::new("zenity")
            .arg("--info")
            .arg("--title=AniList Checker")
            .arg("--width=400")
            .arg("--text=No new episodes and you are fully caught up. Nice!")
            .status();
        return;
    }

    // Build a combined list: Title | Status | Details
    let mut cmd = Command::new("zenity");
    cmd.arg("--list")
        .arg("--title=AniList Checker")
        .arg("--width=700")
        .arg("--height=400")
        .arg("--column=Title")
        .arg("--column=Status")
        .arg("--column=Details");

    for (title, delta, available) in newly_released {
        cmd.arg(title);
        cmd.arg("🆕 New");
        cmd.arg(format!("+{} → now ep {}", delta, available));
    }

    for (title, progress, available) in behind {
        let left = available - progress;
        // Avoid duplicating if it was already shown as "New"
        if newly_released.iter().any(|(t, _, _)| t == title) {
            continue;
        }
        cmd.arg(title);
        cmd.arg("📺 Behind");
        cmd.arg(format!(
            "watched {} / available {}  ({} left)",
            progress, available, left
        ));
    }

    let status = cmd.status();
    match status {
        Ok(s) if s.success() => println!("→ Zenity dialog shown"),
        Ok(_) => {} // user closed the dialog
        Err(e) => eprintln!("⚠  Failed to run zenity: {}. Is zenity installed?", e),
    }
}

fn main() {
    ensure_config_dir();

    let config = match load_config() {
        Some(c) if !c.token.is_empty() => c,
        _ => setup_auth(),
    };

    let user_id = match get_user_id(&config.token) {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Auth failed: {}. Token may be expired.", e);
            eprintln!("Delete ~/.config/anilist-checker/config.json and re-run to re-authenticate.");
            std::process::exit(1);
        }
    };

    let entries = match fetch_watching(&config.token, user_id) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Failed to fetch list: {}", e);
            std::process::exit(1);
        }
    };

    let mut state = load_state();
    let mut newly_released: Vec<(String, u32, u32)> = Vec::new();
    let mut behind: Vec<(String, u32, u32)> = Vec::new();

    for entry in &entries {
        let prev = state
            .available
            .get(&entry.id)
            .copied()
            .unwrap_or(entry.available);

        if entry.available > prev {
            let delta = entry.available - prev;
            newly_released.push((entry.title.clone(), delta, entry.available));
        }

        if entry.available > entry.progress {
            behind.push((entry.title.clone(), entry.progress, entry.available));
        }

        state.available.insert(entry.id, entry.available);
    }

    save_state(&state);

    // ---- Terminal output ----
    println!("════════════════════════════════════════════════════════════");
    println!("  AniList Episode Checker");
    println!("════════════════════════════════════════════════════════════\n");

    if newly_released.is_empty() && behind.is_empty() {
        println!("No new episodes and you are fully caught up. Nice!\n");
    } else {
        if !newly_released.is_empty() {
            println!("🆕  New episodes released since last check\n");
            let headers = ["Title", "New", "Now Available"];
            let rows: Vec<Vec<String>> = newly_released
                .iter()
                .map(|(title, delta, available)| {
                    vec![
                        title.clone(),
                        format!("+{}", delta),
                        format!("ep {}", available),
                    ]
                })
                .collect();
            print_table(&headers, &rows);
            println!();
        }

        if !behind.is_empty() {
            println!("📺  You are behind on\n");
            let headers = ["Title", "Watched", "Available", "Left"];
            let rows: Vec<Vec<String>> = behind
                .iter()
                .map(|(title, progress, available)| {
                    let left = available - progress;
                    vec![
                        title.clone(),
                        progress.to_string(),
                        available.to_string(),
                        left.to_string(),
                    ]
                })
                .collect();
            print_table(&headers, &rows);
            println!();
        }
    }

    // ---- Zenity dialog ----
    show_zenity_dialog(&newly_released, &behind);

    println!("Done.");
}
