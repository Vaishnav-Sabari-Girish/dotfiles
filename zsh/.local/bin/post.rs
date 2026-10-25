#!/usr/bin/env rust-script
//! Post to multiple Mastodon / Bluesky accounts from the command line.
//!
//! ```cargo
//! [package]
//! edition = "2021"
//!
//! [dependencies]
//! anyhow = "*"
//! chrono = "*"
//! clap = { version = "*", features = ["derive"] }
//! dirs = "*"
//! mime_guess = "*"
//! open = "*"
//! rand = "*"
//! regex = "*"
//! reqwest = { version = "*", default-features = false, features = ["blocking", "json", "multipart", "rustls-tls"] }
//! rpassword = "*"
//! serde = { version = "*", features = ["derive"] }
//! serde_json = "*"
//! toml = "*"
//! unicode-segmentation = "*"
//! ```
//!
//! # Usage
//!
//!   post account add mas1 --kind mastodon --instance hachyderm.io   # opens browser to authorize
//!   post account add sky  --kind bluesky  --handle me.bsky.social    # opens app-password page
//!   post account list
//!   post account login mas1      # re-authorize
//!   post account logout mas1     # forget the stored login
//!   post account remove mas1
//!
//!   post "hello world" --to mas1,sky
//!   post --file msg.md --to mas2,mas3
//!   post "look at this" --media a.png --alt "a cat" --media b.png --to mas1,sky
//!   echo "from stdin" | post - --to mas1
//!
//! # Secrets
//!
//! Nothing secret is ever in this script or in the config file
//! (~/.config/post/accounts.toml), so both are safe to commit to dotfiles.
//!
//! Logins (tokens / app passwords) obtained via `post account add|login` are kept
//! in a separate file, ~/.local/share/post/credentials.toml (mode 0600), which you
//! should NOT put in your dotfiles. Secret lookup order for each account:
//!
//!   1. `--secret-cmd "<shell command>"`: stdout is the secret,
//!      e.g. `pass show social/mas1` or `op read op://Personal/mas1/token`
//!   2. the env var named by `--secret-env`, or else `POST_<NAME>_SECRET`
//!   3. the stored login from `post account login`
//!
//! Mastodon: standard OAuth. Your browser opens on your instance, you click
//!           Authorize, and the token comes back to a temporary localhost listener.
//!           Scopes requested: write:statuses write:media.
//! Bluesky:  atproto OAuth needs DPoP/PAR, so this uses an *app password*
//!           instead: the app-passwords page opens in your browser and you paste
//!           the password into the terminal (hidden). Never use your main password.

use anyhow::{anyhow, bail, Context, Result};
use clap::{Args, Parser, Subcommand, ValueEnum};
use regex::Regex;
use reqwest::blocking::{multipart, Client, Response};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, HashMap};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};
use unicode_segmentation::UnicodeSegmentation;

const BSKY_DEFAULT_SERVICE: &str = "https://bsky.social";
const BSKY_MAX_GRAPHEMES: usize = 300;
const BSKY_MAX_IMAGES: usize = 4;
const BSKY_MAX_IMAGE_BYTES: usize = 1_000_000;

// ───────────────────────────── CLI ─────────────────────────────

#[derive(Parser)]
#[command(
    name = "post",
    version,
    about = "Post to Mastodon and Bluesky accounts",
    args_conflicts_with_subcommands = true,
    subcommand_negates_reqs = true
)]
struct Cli {
    #[command(subcommand)]
    cmd: Option<Cmd>,
    #[command(flatten)]
    post: PostArgs,
}

#[derive(Args)]
struct PostArgs {
    /// Text to post (use `-` to read from stdin)
    body: Vec<String>,

    /// Read the post text from a file
    #[arg(short, long, conflicts_with = "body")]
    file: Option<PathBuf>,

    /// Comma-separated account names to post to
    #[arg(short, long, value_delimiter = ',', required = true)]
    to: Vec<String>,

    /// Attach a media file (repeatable)
    #[arg(short, long)]
    media: Vec<PathBuf>,

    /// Alt text for the media, in the same order as --media (repeatable)
    #[arg(short, long)]
    alt: Vec<String>,

    /// Mastodon post visibility (ignored for Bluesky)
    #[arg(long, value_enum, default_value = "public")]
    visibility: Visibility,

    /// Show what would be posted without posting
    #[arg(short = 'n', long)]
    dry_run: bool,
}

#[derive(Clone, Copy, ValueEnum)]
enum Visibility {
    Public,
    Unlisted,
    Private,
    Direct,
}

impl Visibility {
    fn as_str(&self) -> &'static str {
        match self {
            Visibility::Public => "public",
            Visibility::Unlisted => "unlisted",
            Visibility::Private => "private",
            Visibility::Direct => "direct",
        }
    }
}

#[derive(Subcommand)]
enum Cmd {
    /// Manage saved accounts
    #[command(alias = "accounts")]
    Account {
        #[command(subcommand)]
        action: AccountCmd,
    },
}

#[derive(Subcommand)]
enum AccountCmd {
    /// Add or update an account (no secrets are stored)
    Add(AddArgs),
    /// List saved accounts
    List,
    /// Remove an account (and its stored login)
    Remove { name: String },
    /// Authorize an account in your browser and store the login
    Login { name: String },
    /// Forget the stored login for an account
    Logout { name: String },
}

#[derive(Args)]
struct AddArgs {
    /// Name you'll use with --to (e.g. mas1)
    name: String,
    #[arg(long, value_enum)]
    kind: Kind,
    /// Mastodon instance URL, e.g. https://hachyderm.io
    #[arg(long)]
    instance: Option<String>,
    /// Bluesky handle, e.g. me.bsky.social
    #[arg(long)]
    handle: Option<String>,
    /// Bluesky service URL (default https://bsky.social)
    #[arg(long)]
    service: Option<String>,
    /// Name of the env var holding the token / app password
    #[arg(long, conflicts_with = "secret_cmd")]
    secret_env: Option<String>,
    /// Shell command that prints the token / app password
    #[arg(long)]
    secret_cmd: Option<String>,
    /// Don't open the browser to log in now
    #[arg(long)]
    no_login: bool,
}

// ──────────────────────────── Config ────────────────────────────

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "lowercase")]
enum Kind {
    Mastodon,
    Bluesky,
}

impl Kind {
    fn as_str(&self) -> &'static str {
        match self {
            Kind::Mastodon => "mastodon",
            Kind::Bluesky => "bluesky",
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
struct Account {
    kind: Kind,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    instance: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    handle: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    service: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    secret_env: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    secret_cmd: Option<String>,
}

#[derive(Default, Serialize, Deserialize)]
struct Config {
    #[serde(default)]
    accounts: BTreeMap<String, Account>,
}

fn config_path() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("POST_CONFIG") {
        return Ok(p.into());
    }
    let base = match std::env::var("XDG_CONFIG_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x),
        _ => dirs::home_dir()
            .ok_or_else(|| anyhow!("cannot determine home directory"))?
            .join(".config"),
    };
    Ok(base.join("post").join("accounts.toml"))
}

fn load_config() -> Result<Config> {
    let path = config_path()?;
    if !path.exists() {
        return Ok(Config::default());
    }
    let s = std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    toml::from_str(&s).with_context(|| format!("parsing {}", path.display()))
}

fn save_config(cfg: &Config) -> Result<()> {
    let path = config_path()?;
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    std::fs::write(&path, toml::to_string_pretty(cfg)?)
        .with_context(|| format!("writing {}", path.display()))
}

// Stored logins live in a separate, private file (NOT meant for dotfiles).

#[derive(Default, Serialize, Deserialize)]
struct Creds {
    #[serde(default)]
    secrets: BTreeMap<String, String>,
}

fn creds_path() -> Result<PathBuf> {
    if let Ok(p) = std::env::var("POST_CREDENTIALS") {
        return Ok(p.into());
    }
    let base = match std::env::var("XDG_DATA_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x),
        _ => dirs::home_dir()
            .ok_or_else(|| anyhow!("cannot determine home directory"))?
            .join(".local")
            .join("share"),
    };
    Ok(base.join("post").join("credentials.toml"))
}

fn load_creds() -> Result<Creds> {
    let path = creds_path()?;
    if !path.exists() {
        return Ok(Creds::default());
    }
    let s = std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    toml::from_str(&s).with_context(|| format!("parsing {}", path.display()))
}

fn write_private(path: &Path, data: &str) -> Result<()> {
    let mut o = std::fs::OpenOptions::new();
    o.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        o.mode(0o600);
    }
    let mut f = o.open(path)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        f.set_permissions(std::fs::Permissions::from_mode(0o600))?;
    }
    f.write_all(data.as_bytes())?;
    Ok(())
}

fn save_creds(c: &Creds) -> Result<()> {
    let path = creds_path()?;
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    write_private(&path, &toml::to_string_pretty(c)?)
        .with_context(|| format!("writing {}", path.display()))
}

fn http_client(timeout_secs: u64) -> Result<Client> {
    Ok(Client::builder()
        .timeout(Duration::from_secs(timeout_secs))
        .user_agent(concat!("post-script/", env!("CARGO_PKG_VERSION")))
        .build()?)
}

fn default_secret_env(name: &str) -> String {
    format!(
        "POST_{}_SECRET",
        name.to_uppercase().replace(|c: char| !c.is_ascii_alphanumeric(), "_")
    )
}

/// Look up the secret at run time. Never stored anywhere.
fn resolve_secret(name: &str, acc: &Account) -> Result<String> {
    if let Some(cmd) = &acc.secret_cmd {
        let out = Command::new("sh")
            .arg("-c")
            .arg(cmd)
            .output()
            .with_context(|| format!("running secret command for '{name}'"))?;
        if !out.status.success() {
            bail!(
                "secret command for '{name}' failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            );
        }
        let s = String::from_utf8(out.stdout)?.trim().to_string();
        if s.is_empty() {
            bail!("secret command for '{name}' printed nothing");
        }
        return Ok(s);
    }
    let var = acc.secret_env.clone().unwrap_or_else(|| default_secret_env(name));
    if let Ok(s) = std::env::var(&var) {
        if !s.trim().is_empty() {
            return Ok(s.trim().to_string());
        }
    }
    if let Some(s) = load_creds()?.secrets.get(name) {
        return Ok(s.clone());
    }
    bail!("no login for '{name}': run `post account login {name}` (or set ${var})")
}

// ───────────────────────────── Login flows ─────────────────────────────

fn respond(stream: &mut TcpStream, status: &str, body: &str) {
    let page = format!(
        "<!doctype html><meta charset=utf-8><title>post</title>\
         <body style=\"font-family:sans-serif;max-width:30em;margin:4em auto\">{body}</body>"
    );
    let _ = write!(
        stream,
        "HTTP/1.1 {status}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{page}",
        page.len()
    );
}

/// Wait for the browser to hit http://127.0.0.1:PORT/callback?code=...
fn wait_for_code(listener: &TcpListener, state: &str) -> Result<String> {
    listener.set_nonblocking(true)?;
    let deadline = Instant::now() + Duration::from_secs(300);
    loop {
        if Instant::now() > deadline {
            bail!("timed out waiting for authorization (5 minutes)");
        }
        let mut stream = match listener.accept() {
            Ok((s, _)) => s,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(100));
                continue;
            }
            Err(e) => return Err(e.into()),
        };
        stream.set_nonblocking(false)?;
        stream.set_read_timeout(Some(Duration::from_secs(5)))?;
        let mut buf = [0u8; 8192];
        let n = stream.read(&mut buf).unwrap_or(0);
        let req = String::from_utf8_lossy(&buf[..n]).into_owned();
        let path = req.lines().next().and_then(|l| l.split_whitespace().nth(1)).unwrap_or("/");
        let url = match reqwest::Url::parse(&format!("http://127.0.0.1{path}")) {
            Ok(u) => u,
            Err(_) => continue,
        };
        if url.path() != "/callback" {
            respond(&mut stream, "404 Not Found", "Not found");
            continue;
        }
        let q: HashMap<String, String> = url.query_pairs().into_owned().collect();
        if let Some(err) = q.get("error") {
            respond(&mut stream, "200 OK", "<h2>Authorization failed</h2>You can close this tab.");
            bail!(
                "authorization denied: {err} {}",
                q.get("error_description").cloned().unwrap_or_default()
            );
        }
        if q.get("state").map(String::as_str) != Some(state) {
            respond(&mut stream, "400 Bad Request", "State mismatch; try again.");
            bail!("authorization response had the wrong state value");
        }
        if let Some(code) = q.get("code") {
            respond(&mut stream, "200 OK", "<h2>Authorized ✓</h2>You can close this tab and go back to the terminal.");
            return Ok(code.clone());
        }
        respond(&mut stream, "400 Bad Request", "Missing code");
    }
}

fn open_browser(url: &str) {
    println!("Opening your browser. If it doesn't open, visit:\n  {url}\n");
    let _ = open::that(url);
}

fn login_mastodon(http: &Client, acc: &Account) -> Result<String> {
    let base = acc
        .instance
        .as_deref()
        .ok_or_else(|| anyhow!("account has no instance"))?
        .trim_end_matches('/');
    let scopes = "write:statuses write:media";

    let listener = TcpListener::bind("127.0.0.1:0")?;
    let port = listener.local_addr()?.port();
    let redirect = format!("http://127.0.0.1:{port}/callback");

    // Register a client on the instance (standard for CLI apps).
    let (_, app) = json_ok(
        http.post(format!("{base}/api/v1/apps"))
            .form(&[
                ("client_name", "post (CLI)"),
                ("redirect_uris", redirect.as_str()),
                ("scopes", scopes),
            ])
            .send()?,
    )
    .context("registering app with the instance")?;
    let client_id = app["client_id"].as_str().ok_or_else(|| anyhow!("no client_id returned"))?;
    let client_secret = app["client_secret"].as_str().ok_or_else(|| anyhow!("no client_secret returned"))?;

    let state = format!("{:016x}", rand::random::<u64>());
    let auth = reqwest::Url::parse_with_params(
        &format!("{base}/oauth/authorize"),
        &[
            ("response_type", "code"),
            ("client_id", client_id),
            ("redirect_uri", redirect.as_str()),
            ("scope", scopes),
            ("state", state.as_str()),
        ],
    )?;
    open_browser(auth.as_str());
    println!("Waiting for you to authorize...");
    let code = wait_for_code(&listener, &state)?;

    let (_, tok) = json_ok(
        http.post(format!("{base}/oauth/token"))
            .form(&[
                ("grant_type", "authorization_code"),
                ("code", code.as_str()),
                ("client_id", client_id),
                ("client_secret", client_secret),
                ("redirect_uri", redirect.as_str()),
                ("scope", scopes),
            ])
            .send()?,
    )
    .context("exchanging code for token")?;
    let token = tok["access_token"]
        .as_str()
        .ok_or_else(|| anyhow!("no access_token returned"))?
        .to_string();

    if let Ok(r) = http
        .get(format!("{base}/api/v1/accounts/verify_credentials"))
        .bearer_auth(&token)
        .send()
    {
        if let Ok((_, v)) = json_ok(r) {
            println!("Authorized as @{}", v["acct"].as_str().unwrap_or("?"));
        }
    }
    Ok(token)
}

fn login_bluesky(http: &Client, acc: &Account) -> Result<String> {
    let service = acc.service.as_deref().unwrap_or(BSKY_DEFAULT_SERVICE).trim_end_matches('/');
    let handle = acc.handle.as_deref().ok_or_else(|| anyhow!("account has no handle"))?;
    println!("Create an app password (name it e.g. \"post-cli\"), then paste it below.");
    open_browser("https://bsky.app/settings/app-passwords");
    let pw = rpassword::prompt_password("App password (input hidden): ")?;
    let pw = pw.trim().to_string();
    if pw.is_empty() {
        bail!("no password entered");
    }
    bsky_session(http, service, handle, &pw).context("login failed: check the handle and app password")?;
    println!("Authorized as @{handle}");
    Ok(pw)
}

fn login(name: &str, acc: &Account) -> Result<()> {
    let http = http_client(30)?;
    let secret = match acc.kind {
        Kind::Mastodon => login_mastodon(&http, acc)?,
        Kind::Bluesky => login_bluesky(&http, acc)?,
    };
    let mut c = load_creds()?;
    c.secrets.insert(name.to_string(), secret);
    save_creds(&c)?;
    println!("Saved login for '{name}' to {}", creds_path()?.display());
    Ok(())
}

fn bsky_session(http: &Client, service: &str, handle: &str, password: &str) -> Result<Value> {
    let (_, sess) = json_ok(
        http.post(format!("{service}/xrpc/com.atproto.server.createSession"))
            .json(&json!({ "identifier": handle, "password": password }))
            .send()?,
    )?;
    Ok(sess)
}

// ───────────────────────── Account commands ─────────────────────────

fn account_cmd(action: AccountCmd) -> Result<()> {
    let mut cfg = load_config()?;
    match action {
        AccountCmd::Add(a) => {
            if a.name.is_empty()
                || !a.name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
            {
                bail!("account name may only contain letters, digits, '-' and '_'");
            }
            let mut acc = Account {
                kind: a.kind,
                instance: None,
                handle: None,
                service: None,
                secret_env: a.secret_env,
                secret_cmd: a.secret_cmd,
            };
            match a.kind {
                Kind::Mastodon => {
                    let inst = a.instance.ok_or_else(|| anyhow!("--instance is required for mastodon"))?;
                    let inst = if inst.contains("://") { inst } else { format!("https://{inst}") };
                    acc.instance = Some(inst.trim_end_matches('/').to_string());
                }
                Kind::Bluesky => {
                    let h = a.handle.ok_or_else(|| anyhow!("--handle is required for bluesky"))?;
                    acc.handle = Some(h.trim_start_matches('@').to_string());
                    acc.service = a.service.map(|s| s.trim_end_matches('/').to_string());
                }
            }
            let existed = cfg.accounts.insert(a.name.clone(), acc.clone()).is_some();
            save_config(&cfg)?;
            println!("{} account '{}'", if existed { "Updated" } else { "Added" }, a.name);
            if acc.secret_cmd.is_none() && acc.secret_env.is_none() {
                if a.no_login {
                    println!("Run `post account login {}` to authorize it.", a.name);
                } else {
                    login(&a.name, &acc)?;
                }
            }
        }
        AccountCmd::Login { name } => {
            let acc = cfg.accounts.get(&name).ok_or_else(|| anyhow!("no such account '{name}'"))?;
            login(&name, acc)?;
        }
        AccountCmd::Logout { name } => {
            let mut c = load_creds()?;
            if c.secrets.remove(&name).is_none() {
                bail!("no stored login for '{name}'");
            }
            save_creds(&c)?;
            println!("Forgot stored login for '{name}'");
        }
        AccountCmd::List => {
            if cfg.accounts.is_empty() {
                println!("No accounts yet. Try: post account add mas1 --kind mastodon --instance https://example.social");
            }
            for (name, a) in &cfg.accounts {
                let target = match a.kind {
                    Kind::Mastodon => a.instance.clone().unwrap_or_default(),
                    Kind::Bluesky => format!(
                        "@{} on {}",
                        a.handle.clone().unwrap_or_default(),
                        a.service.clone().unwrap_or_else(|| BSKY_DEFAULT_SERVICE.into())
                    ),
                };
                let secret = if let Some(c) = &a.secret_cmd {
                    format!("cmd: {c}")
                } else {
                    let var = a.secret_env.clone().unwrap_or_else(|| default_secret_env(name));
                    let set = std::env::var(&var).map(|v| !v.is_empty()).unwrap_or(false);
                    let stored = load_creds().map(|c| c.secrets.contains_key(name)).unwrap_or(false);
                    if set {
                        format!("env: ${var}")
                    } else if stored {
                        "stored login".to_string()
                    } else {
                        format!("NOT LOGGED IN: run `post account login {name}`")
                    }
                };
                println!("{name:<12} {:<9} {target}  [{secret}]", a.kind.as_str());
            }
        }
        AccountCmd::Remove { name } => {
            if cfg.accounts.remove(&name).is_none() {
                bail!("no such account '{name}'");
            }
            save_config(&cfg)?;
            let mut c = load_creds()?;
            if c.secrets.remove(&name).is_some() {
                save_creds(&c)?;
            }
            println!("Removed account '{name}'");
        }
    }
    Ok(())
}

// ───────────────────────────── HTTP helpers ─────────────────────────────

fn json_ok(resp: Response) -> Result<(u16, Value)> {
    let status = resp.status();
    let text = resp.text()?;
    if !status.is_success() {
        let snippet: String = text.chars().take(300).collect();
        bail!("HTTP {}: {}", status.as_u16(), snippet);
    }
    let v = if text.trim().is_empty() { Value::Null } else { serde_json::from_str(&text)? };
    Ok((status.as_u16(), v))
}

struct Media {
    name: String,
    mime: String,
    alt: Option<String>,
    bytes: Vec<u8>,
}

// ───────────────────────────── Mastodon ─────────────────────────────

fn post_mastodon(
    http: &Client,
    acc: &Account,
    token: &str,
    text: &str,
    media: &[Media],
    vis: Visibility,
) -> Result<String> {
    let base = acc
        .instance
        .as_deref()
        .ok_or_else(|| anyhow!("account has no instance"))?
        .trim_end_matches('/');

    let mut ids: Vec<String> = Vec::new();
    for m in media {
        let part = multipart::Part::bytes(m.bytes.clone())
            .file_name(m.name.clone())
            .mime_str(&m.mime)?;
        let mut form = multipart::Form::new().part("file", part);
        if let Some(alt) = &m.alt {
            form = form.text("description", alt.clone());
        }
        let resp = http
            .post(format!("{base}/api/v2/media"))
            .bearer_auth(token)
            .multipart(form)
            .send()
            .with_context(|| format!("uploading {}", m.name))?;
        let (code, v) = json_ok(resp).with_context(|| format!("uploading {}", m.name))?;
        let id = v["id"].as_str().ok_or_else(|| anyhow!("media upload returned no id"))?.to_string();

        // 202 = still processing (video, large images); poll until ready.
        if code == 202 {
            let mut ready = false;
            for _ in 0..60 {
                thread::sleep(Duration::from_secs(2));
                let r = http
                    .get(format!("{base}/api/v1/media/{id}"))
                    .bearer_auth(token)
                    .send()?;
                let st = r.status().as_u16();
                if st == 200 {
                    ready = true;
                    break;
                }
                if !r.status().is_success() {
                    bail!("media processing failed (HTTP {st})");
                }
            }
            if !ready {
                bail!("timed out waiting for {} to process", m.name);
            }
        }
        ids.push(id);
    }

    let body = json!({
        "status": text,
        "visibility": vis.as_str(),
        "media_ids": ids,
    });
    let resp = http
        .post(format!("{base}/api/v1/statuses"))
        .bearer_auth(token)
        .json(&body)
        .send()?;
    let (_, v) = json_ok(resp)?;
    Ok(v["url"].as_str().unwrap_or("(posted)").to_string())
}

// ───────────────────────────── Bluesky ─────────────────────────────

fn facet(start: usize, end: usize, feature: Value) -> Value {
    json!({
        "index": { "byteStart": start, "byteEnd": end },
        "features": [feature],
    })
}

/// Bluesky doesn't auto-link anything; links, #tags and @mentions need facets
/// with UTF-8 byte offsets.
fn build_facets(http: &Client, service: &str, text: &str) -> Vec<Value> {
    let mut out = Vec::new();

    let url_re = Regex::new(r"https?://[^\s]+").unwrap();
    for m in url_re.find_iter(text) {
        let url = m.as_str().trim_end_matches(|c: char| ".,;:!?)]}'\"".contains(c));
        if url.len() <= "https://".len() {
            continue;
        }
        out.push(facet(
            m.start(),
            m.start() + url.len(),
            json!({ "$type": "app.bsky.richtext.facet#link", "uri": url }),
        ));
    }

    let tag_re = Regex::new(r"(?:^|\s)#([\p{L}\p{N}_]+)").unwrap();
    for c in tag_re.captures_iter(text) {
        let g = c.get(1).unwrap();
        if g.as_str().chars().all(|ch| ch.is_ascii_digit()) {
            continue;
        }
        out.push(facet(
            g.start() - 1, // include the '#'
            g.end(),
            json!({ "$type": "app.bsky.richtext.facet#tag", "tag": g.as_str() }),
        ));
    }

    let men_re = Regex::new(r"(?:^|\s)@([a-zA-Z0-9][a-zA-Z0-9.-]*)").unwrap();
    for c in men_re.captures_iter(text) {
        let g = c.get(1).unwrap();
        let handle = g.as_str().trim_end_matches(|ch: char| ch == '.' || ch == '-');
        if !handle.contains('.') {
            continue;
        }
        let resolved = http
            .get(format!("{service}/xrpc/com.atproto.identity.resolveHandle"))
            .query(&[("handle", handle)])
            .send()
            .ok()
            .and_then(|r| json_ok(r).ok());
        if let Some((_, v)) = resolved {
            if let Some(did) = v["did"].as_str() {
                out.push(facet(
                    g.start() - 1, // include the '@'
                    g.start() + handle.len(),
                    json!({ "$type": "app.bsky.richtext.facet#mention", "did": did }),
                ));
            }
        }
    }
    out
}

fn post_bluesky(http: &Client, acc: &Account, password: &str, text: &str, media: &[Media]) -> Result<String> {
    let service = acc
        .service
        .as_deref()
        .unwrap_or(BSKY_DEFAULT_SERVICE)
        .trim_end_matches('/');
    let handle = acc.handle.as_deref().ok_or_else(|| anyhow!("account has no handle"))?;

    let graphemes = text.graphemes(true).count();
    if graphemes > BSKY_MAX_GRAPHEMES {
        bail!("text is {graphemes} characters; Bluesky's limit is {BSKY_MAX_GRAPHEMES}");
    }
    if media.len() > BSKY_MAX_IMAGES {
        bail!("Bluesky allows at most {BSKY_MAX_IMAGES} images per post");
    }
    for m in media {
        if !m.mime.starts_with("image/") {
            bail!("{}: only images are supported for Bluesky (got {})", m.name, m.mime);
        }
        if m.bytes.len() > BSKY_MAX_IMAGE_BYTES {
            bail!(
                "{}: {} bytes exceeds Bluesky's {} byte image limit",
                m.name,
                m.bytes.len(),
                BSKY_MAX_IMAGE_BYTES
            );
        }
    }

    let sess = bsky_session(http, service, handle, password)
        .context("bluesky login failed (use an app password; try `post account login`)")?;
    let jwt = sess["accessJwt"].as_str().ok_or_else(|| anyhow!("no accessJwt in session"))?;
    let did = sess["did"].as_str().ok_or_else(|| anyhow!("no did in session"))?;

    let mut images = Vec::new();
    for m in media {
        let (_, v) = json_ok(
            http.post(format!("{service}/xrpc/com.atproto.repo.uploadBlob"))
                .bearer_auth(jwt)
                .header(reqwest::header::CONTENT_TYPE, &m.mime)
                .body(m.bytes.clone())
                .send()?,
        )
        .with_context(|| format!("uploading {}", m.name))?;
        images.push(json!({ "alt": m.alt.clone().unwrap_or_default(), "image": v["blob"] }));
    }

    let mut record = json!({
        "$type": "app.bsky.feed.post",
        "text": text,
        "createdAt": chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
    });
    let facets = build_facets(http, service, text);
    if !facets.is_empty() {
        record["facets"] = Value::Array(facets);
    }
    if !images.is_empty() {
        record["embed"] = json!({ "$type": "app.bsky.embed.images", "images": images });
    }

    let (_, v) = json_ok(
        http.post(format!("{service}/xrpc/com.atproto.repo.createRecord"))
            .bearer_auth(jwt)
            .json(&json!({
                "repo": did,
                "collection": "app.bsky.feed.post",
                "record": record,
            }))
            .send()?,
    )?;
    let uri = v["uri"].as_str().unwrap_or_default();
    let rkey = uri.rsplit('/').next().unwrap_or_default();
    Ok(format!("https://bsky.app/profile/{handle}/post/{rkey}"))
}

// ───────────────────────────── Main flow ─────────────────────────────

fn run_post(args: PostArgs) -> Result<()> {
    // Body: --file, stdin ("-"), or the positional words.
    let mut body = if let Some(f) = &args.file {
        std::fs::read_to_string(f).with_context(|| format!("reading {}", f.display()))?
    } else if args.body.len() == 1 && args.body[0] == "-" {
        let mut s = String::new();
        std::io::stdin().read_to_string(&mut s)?;
        s
    } else {
        args.body.join(" ")
    };
    body = body.trim_end().to_string();
    if body.is_empty() && args.media.is_empty() {
        bail!("nothing to post: give some text, --file, or --media");
    }
    if args.alt.len() > args.media.len() {
        bail!("more --alt values ({}) than --media files ({})", args.alt.len(), args.media.len());
    }

    // Resolve targets before doing anything, so typos fail fast.
    let cfg = load_config()?;
    let mut targets: Vec<(String, Account)> = Vec::new();
    for name in &args.to {
        let name = name.trim();
        if name.is_empty() || targets.iter().any(|(n, _)| n == name) {
            continue;
        }
        let acc = cfg.accounts.get(name).ok_or_else(|| {
            let known: Vec<_> = cfg.accounts.keys().cloned().collect();
            anyhow!("unknown account '{name}' (known: {})", if known.is_empty() { "none".into() } else { known.join(", ") })
        })?;
        targets.push((name.to_string(), acc.clone()));
    }

    // Load media once.
    let mut media = Vec::new();
    for (i, p) in args.media.iter().enumerate() {
        let bytes = std::fs::read(p).with_context(|| format!("reading {}", p.display()))?;
        media.push(Media {
            name: p.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| "file".into()),
            mime: mime_guess::from_path(p).first_or_octet_stream().to_string(),
            alt: args.alt.get(i).cloned(),
            bytes,
        });
    }

    if args.dry_run {
        println!("--- text ({} chars) ---\n{}\n---", body.graphemes(true).count(), body);
        for m in &media {
            println!("media: {} ({}, {} bytes, alt: {:?})", m.name, m.mime, m.bytes.len(), m.alt);
        }
        for (name, acc) in &targets {
            println!("would post to {name} ({})", acc.kind.as_str());
        }
        return Ok(());
    }

    let http = http_client(120)?;

    let mut failures = 0;
    for (name, acc) in &targets {
        let result = resolve_secret(name, acc).and_then(|secret| match acc.kind {
            Kind::Mastodon => post_mastodon(&http, acc, &secret, &body, &media, args.visibility),
            Kind::Bluesky => post_bluesky(&http, acc, &secret, &body, &media),
        });
        match result {
            Ok(url) => println!("✓ {name}: {url}"),
            Err(e) => {
                failures += 1;
                eprintln!("✗ {name}: {e:#}");
            }
        }
    }
    if failures > 0 {
        std::process::exit(1);
    }
    Ok(())
}

fn main() {
    let cli = Cli::parse();
    let result = match cli.cmd {
        Some(Cmd::Account { action }) => account_cmd(action),
        None => run_post(cli.post),
    };
    if let Err(e) = result {
        eprintln!("error: {e:#}");
        std::process::exit(1);
    }
}
