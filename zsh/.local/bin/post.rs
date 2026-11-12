#!/usr/bin/env rust-script
//! Post to multiple Mastodon / Bluesky / Twitter(X) / dev-null accounts from the command line.
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
//! sha2 = "*"
//! toml = "*"
//! unicode-segmentation = "*"
//! ```
//!
//! # Usage
//!
//!   post account add mas1 --kind mastodon --instance hachyderm.io   # opens browser to authorize
//!   post account add sky  --kind bluesky  --handle me.bsky.social    # opens app-password page
//!   post account add tw   --kind twitter                             # uses your browser's x.com login
//!   post account add tw2  --kind twitter --browser firefox           # ...from a specific browser
//!   post account add dn   --kind devnull                             # signs with an SSH key on your GitHub account
//!   post account add dn2  --kind devnull --key ~/.ssh/id_dn          # ...a specific key (or a .pub held by ssh-agent)
//!   post account list
//!   post account login mas1      # re-authorize (for twitter: store auth_token + ct0 explicitly)
//!   post account logout mas1     # forget the stored login
//!   post account remove mas1
//!
//!   post "hello world" --to mas1,sky,tw,dn
//!   post --file msg.md --to mas2,mas3
//!   post "look at this" --media a.png --alt "a cat" --media b.png --to mas1,sky,dn
//!   post "agreed" --to dn --reply-to 0be0130     # dev-null: reply to a commit
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
//! Twitter:  posts through the unofficial `twitter-cli`
//!           (https://github.com/public-clis/twitter-cli; `uv tool install twitter-cli`),
//!           which uses your x.com web session instead of the paid API.
//!           - By default it reads the cookies of a browser you're logged in to
//!             (`--browser`, and `--profile "Profile 2"` for Chrome profiles).
//!           - Or store `auth_token` and `ct0` with `post account login`; the secret is
//!             `AUTH_TOKEN:CT0` (`--secret-env`/`--secret-cmd` must print that too).
//!           Unofficial: automating the web client can get an account rate-limited or
//!           suspended, and it can break when X changes things. Up to 4 images, no alt
//!           text. Set POST_TWITTER_BIN if the executable isn't called `twitter`.
//! dev-null: https://dev-null.sh. No token or login: each commit is signed locally with
//!           `ssh-keygen -Y sign` (OpenSSH 8.1+) using an SSH key on your GitHub account;
//!           /dev/null is asked which of your local keys (ssh-agent, ~/.ssh/*.pub) that is.
//!           `--key` skips that lookup and signs with the given key (a private key file, or
//!           a `.pub` whose private half is in ssh-agent). `--instance` points at a
//!           self-hosted server. `--reply-to` replies to a commit. Up to 3 images
//!           (JPEG/PNG/WebP, 10 MB each), no alt text.
use anyhow::{anyhow, bail, Context, Result};
use clap::{Args, Parser, Subcommand, ValueEnum};
use regex::Regex;
use reqwest::blocking::{multipart, Client, Response};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, HashMap};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use unicode_segmentation::UnicodeSegmentation;
const BSKY_DEFAULT_SERVICE: &str = "https://bsky.social";
const BSKY_MAX_GRAPHEMES: usize = 300;
const BSKY_MAX_IMAGES: usize = 4;
const BSKY_MAX_IMAGE_BYTES: usize = 1_000_000;
const TWITTER_SOFT_LIMIT: usize = 280;
const TWITTER_MAX_IMAGES: usize = 4;
const TWITTER_IMAGE_MIMES: [&str; 4] = ["image/jpeg", "image/png", "image/gif", "image/webp"];
const DEVNULL_DEFAULT_URL: &str = "https://dev-null.sh";
const DEVNULL_NAMESPACE: &str = "devnull-commit";
const DEVNULL_IMAGES_NAMESPACE: &str = "devnull-commit-images";
const DEVNULL_MAX_IMAGES: usize = 3;
const DEVNULL_MAX_IMAGE_BYTES: usize = 10_240_000;
const DEVNULL_IMAGE_MIMES: [&str; 3] = ["image/jpeg", "image/png", "image/webp"];
// ───────────────────────────── CLI ─────────────────────────────
#[derive(Parser)]
#[command(
    name = "post",
    version,
    about = "Post to Mastodon, Bluesky, Twitter/X and dev-null accounts",
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
    /// Mastodon post visibility (ignored for Bluesky, Twitter and dev-null)
    #[arg(long, value_enum, default_value = "public")]
    visibility: Visibility,
    /// dev-null: short hash, UUID or link of the commit to reply to
    #[arg(long)]
    reply_to: Option<String>,
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
    /// Mastodon instance URL (e.g. https://hachyderm.io), or a self-hosted dev-null URL
    #[arg(long)]
    instance: Option<String>,
    /// Bluesky handle, e.g. me.bsky.social
    #[arg(long)]
    handle: Option<String>,
    /// Bluesky service URL (default https://bsky.social)
    #[arg(long)]
    service: Option<String>,
    /// Twitter: Chrome profile name to read cookies from, e.g. "Profile 2"
    #[arg(long)]
    profile: Option<String>,
    /// Twitter: browser to read x.com cookies from (arc, chrome, edge, firefox, brave)
    #[arg(long)]
    browser: Option<String>,
    /// dev-null: SSH key to sign with (private key file, or a .pub held by ssh-agent)
    #[arg(long)]
    key: Option<String>,
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
    Twitter,
    Devnull,
}
impl Kind {
    fn as_str(&self) -> &'static str {
        match self {
            Kind::Mastodon => "mastodon",
            Kind::Bluesky => "bluesky",
            Kind::Twitter => "twitter",
            Kind::Devnull => "devnull",
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
    browser: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    profile: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    key: Option<String>,
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
/// Look up the secret at run time. Never stored anywhere except the private
/// credentials file. Returns Ok(None) if there simply isn't one.
fn lookup_secret(name: &str, acc: &Account) -> Result<Option<String>> {
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
        return Ok(Some(s));
    }
    let var = acc.secret_env.clone().unwrap_or_else(|| default_secret_env(name));
    if let Ok(s) = std::env::var(&var) {
        if !s.trim().is_empty() {
            return Ok(Some(s.trim().to_string()));
        }
    }
    Ok(load_creds()?.secrets.get(name).cloned())
}
fn resolve_secret(name: &str, acc: &Account) -> Result<String> {
    match lookup_secret(name, acc)? {
        Some(s) => Ok(s),
        None => {
            let var = acc.secret_env.clone().unwrap_or_else(|| default_secret_env(name));
            bail!("no login for '{name}': run `post account login {name}` (or set ${var})")
        }
    }
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
        Kind::Twitter => login_twitter(acc)?,
        Kind::Devnull => {
            println!("dev-null has no login: commits are signed with an SSH key on your GitHub account.");
            return Ok(());
        }
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
                browser: None,
                profile: None,
                key: None,
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
                Kind::Twitter => {
                    acc.browser = a.browser;
                    acc.profile = a.profile;
                }
                Kind::Devnull => {
                    acc.instance = a.instance.map(|i| {
                        let i = if i.contains("://") { i } else { format!("https://{i}") };
                        i.trim_end_matches('/').to_string()
                    });
                    acc.key = a.key;
                }
            }
            let existed = cfg.accounts.insert(a.name.clone(), acc.clone()).is_some();
            save_config(&cfg)?;
            println!("{} account '{}'", if existed { "Updated" } else { "Added" }, a.name);
            if acc.kind == Kind::Twitter {
                println!(
                    "twitter-cli will use the x.com cookies of your logged-in browser. \
                     To store auth_token/ct0 instead, run `post account login {}`.",
                    a.name
                );
            } else if acc.kind == Kind::Devnull {
                println!("dev-null signs with an SSH key on your GitHub account; no login needed.");
            } else if acc.secret_cmd.is_none() && acc.secret_env.is_none() {
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
                    Kind::Twitter => {
                        let mut t = String::from("x.com (twitter-cli");
                        if let Some(b) = &a.browser {
                            t.push_str(&format!(", browser: {b}"));
                        }
                        if let Some(p) = &a.profile {
                            t.push_str(&format!(", profile: {p}"));
                        }
                        t.push(')');
                        t
                    }
                    Kind::Devnull => a.instance.clone().unwrap_or_else(|| DEVNULL_DEFAULT_URL.into()),
                };
                let secret = if a.kind == Kind::Devnull {
                    match &a.key {
                        Some(k) => format!("ssh key: {k}"),
                        None => "ssh key: auto (agent / ~/.ssh)".to_string(),
                    }
                } else if let Some(c) = &a.secret_cmd {
                    format!("cmd: {c}")
                } else {
                    let var = a.secret_env.clone().unwrap_or_else(|| default_secret_env(name));
                    let set = std::env::var(&var).map(|v| !v.is_empty()).unwrap_or(false);
                    let stored = load_creds().map(|c| c.secrets.contains_key(name)).unwrap_or(false);
                    if set {
                        format!("env: ${var}")
                    } else if stored {
                        "stored login".to_string()
                    } else if a.kind == Kind::Twitter {
                        "browser cookies".to_string()
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
    path: PathBuf,
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
// ───────────────────────────── Twitter / X (via twitter-cli, unofficial) ─────────────────────────────
/// Depth-first search for the first non-empty string / number under any of `keys`.
fn find_key(v: &Value, keys: &[&str]) -> Option<String> {
    match v {
        Value::Object(m) => {
            for k in keys {
                match m.get(*k) {
                    Some(Value::String(s)) if !s.is_empty() => return Some(s.clone()),
                    Some(Value::Number(n)) => return Some(n.to_string()),
                    _ => {}
                }
            }
            m.values().find_map(|x| find_key(x, keys))
        }
        Value::Array(a) => a.iter().find_map(|x| find_key(x, keys)),
        _ => None,
    }
}
/// Run `twitter <args>` and return its parsed `--json` envelope
/// (`{ok, data}` / `{ok:false, error:{code,message}}`).
/// With a secret ("AUTH_TOKEN:CT0") the cookies are passed via the environment;
/// without one, twitter-cli reads them from a logged-in browser.
fn run_twitter(acc: &Account, secret: Option<&str>, args: &[&str]) -> Result<Value> {
    let bin = std::env::var("POST_TWITTER_BIN").unwrap_or_else(|_| "twitter".into());
    let mut cmd = Command::new(&bin);
    cmd.args(args).stdin(Stdio::null());
    if let Some(s) = secret {
        let (auth, ct0) = s
            .split_once(':')
            .ok_or_else(|| anyhow!("twitter secret must look like AUTH_TOKEN:CT0"))?;
        cmd.env("TWITTER_AUTH_TOKEN", auth.trim()).env("TWITTER_CT0", ct0.trim());
    }
    if let Some(b) = &acc.browser {
        cmd.env("TWITTER_BROWSER", b);
    }
    if let Some(p) = &acc.profile {
        cmd.env("TWITTER_CHROME_PROFILE", p);
    }
    let out = cmd.output().map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            anyhow!("`{bin}` not found: install twitter-cli with `uv tool install twitter-cli` (or set POST_TWITTER_BIN)")
        } else {
            anyhow!("running `{bin}`: {e}")
        }
    })?;
    let stdout = String::from_utf8_lossy(&out.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
    // Be tolerant of any banner text before the JSON.
    let parsed: Option<Value> = stdout
        .find('{')
        .and_then(|i| serde_json::from_str(stdout[i..].trim()).ok());
    if let Some(v) = &parsed {
        if v["ok"].as_bool() == Some(false) {
            let msg = v["error"]["message"].as_str().unwrap_or("unknown error");
            let hint = if msg.contains("Failed to create tweet") {
                " (X returned no tweet: often transient or the text was rejected; retry, or try `twitter post` directly)"
            } else {
                ""
            };
            bail!(
                "twitter-cli: {}: {msg}{hint}",
                v["error"]["code"].as_str().unwrap_or("error")
            );
        }
    }
    if !out.status.success() {
        let msg = if stderr.trim().is_empty() { stdout.trim() } else { stderr.trim() };
        let snippet: String = msg.chars().take(300).collect();
        bail!("twitter-cli exited with {}: {}", out.status, snippet);
    }
    parsed.ok_or_else(|| {
        let snippet: String = stdout.chars().take(300).collect();
        anyhow!("unexpected output from twitter-cli: {snippet}")
    })
}
/// Optionally store explicit x.com session cookies (twitter-cli can also read
/// them straight from a logged-in browser).
fn login_twitter(acc: &Account) -> Result<String> {
    println!(
        "twitter-cli can reuse the cookies of a browser that's logged in to x.com, so this step\n\
         is optional. To store explicit cookies instead (e.g. for a second account), log in to\n\
         x.com, open DevTools -> Application/Storage -> Cookies -> https://x.com, and copy the\n\
         values of `auth_token` and `ct0`.\n"
    );
    open_browser("https://x.com/home");
    let auth = rpassword::prompt_password("auth_token (input hidden): ")?.trim().to_string();
    let ct0 = rpassword::prompt_password("ct0 (input hidden): ")?.trim().to_string();
    if auth.is_empty() || ct0.is_empty() {
        bail!("both auth_token and ct0 are required");
    }
    let secret = format!("{auth}:{ct0}");
    let v = run_twitter(acc, Some(&secret), &["whoami", "--json"])
        .context("login failed: check the cookies (and that twitter-cli is installed)")?;
    let who = find_key(&v["data"], &["screenName", "screen_name", "username"]).unwrap_or_else(|| "?".into());
    println!("Authorized as @{who}");
    Ok(secret)
}
fn post_twitter(acc: &Account, secret: Option<&str>, text: &str, media: &[Media]) -> Result<String> {
    if text.trim().is_empty() {
        bail!("twitter-cli needs some text to go with the post");
    }
    let n = text.graphemes(true).count();
    if n > TWITTER_SOFT_LIMIT {
        eprintln!("warning: text is {n} characters; X's limit is {TWITTER_SOFT_LIMIT} unless the account is Premium");
    }
    if media.len() > TWITTER_MAX_IMAGES {
        bail!("twitter-cli supports at most {TWITTER_MAX_IMAGES} images per post");
    }
    for m in media {
        if !TWITTER_IMAGE_MIMES.contains(&m.mime.as_str()) {
            bail!("{}: twitter-cli only supports JPEG/PNG/GIF/WebP images (got {})", m.name, m.mime);
        }
        if m.alt.is_some() {
            eprintln!("warning: twitter-cli can't set alt text; ignoring alt for {}", m.name);
        }
    }
    let mut args: Vec<String> = vec!["post".into(), "--json".into()];
    for m in media {
        args.push("-i".into());
        args.push(m.path.to_string_lossy().into_owned());
    }
    args.push("--".into()); // so text starting with '-' isn't read as a flag
    args.push(text.to_string());
    let refs: Vec<&str> = args.iter().map(String::as_str).collect();
    let v = run_twitter(acc, secret, &refs)?;
    let data = &v["data"];
    if let Some(url) = find_key(data, &["url"]).filter(|u| u.starts_with("http")) {
        return Ok(url);
    }
    Ok(match find_key(data, &["id", "rest_id", "tweet_id", "tweetId"]) {
        Some(id) => format!("https://x.com/i/status/{id}"),
        None => "(posted)".to_string(),
    })
}
// ───────────────────────────── dev-null.sh ─────────────────────────────
fn expand_tilde(p: &str) -> String {
    match (p.strip_prefix("~/"), dirs::home_dir()) {
        (Some(rest), Some(h)) => h.join(rest).to_string_lossy().into_owned(),
        _ => p.to_string(),
    }
}
/// Removes control characters (such as terminal escape sequences) from text we print.
fn sanitize(s: &str) -> String {
    s.chars().filter(|c| !matches!(*c as u32, 0..=8 | 0x0b..=0x1f | 0x7f)).collect()
}
/// A private (0700) temp directory, removed when dropped.
struct TmpDir(PathBuf);
impl TmpDir {
    fn new() -> Result<Self> {
        let dir = std::env::temp_dir().join(format!("devnull.{:016x}", rand::random::<u64>()));
        let mut b = std::fs::DirBuilder::new();
        #[cfg(unix)]
        {
            use std::os::unix::fs::DirBuilderExt;
            b.mode(0o700);
        }
        b.create(&dir).with_context(|| format!("creating {}", dir.display()))?;
        Ok(TmpDir(dir))
    }
}
impl Drop for TmpDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
fn is_supported_key(line: &str) -> bool {
    line.starts_with("ssh-ed25519 ") || line.starts_with("ssh-rsa ")
}
/// "<type> <base64>", without the comment.
fn key_id(line: &str) -> String {
    line.split_whitespace().take(2).collect::<Vec<_>>().join(" ")
}
fn agent_keys() -> Vec<String> {
    Command::new("ssh-add")
        .arg("-L")
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .filter(|l| is_supported_key(l))
                .map(key_id)
                .collect()
        })
        .unwrap_or_default()
}
/// (key id, private key path) for each ~/.ssh/*.pub that has a private key next to it.
fn ssh_dir_keys() -> Vec<(String, PathBuf)> {
    let Some(home) = dirs::home_dir() else { return vec![] };
    let Ok(rd) = std::fs::read_dir(home.join(".ssh")) else { return vec![] };
    let mut pubs: Vec<PathBuf> = rd
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().map_or(false, |x| x == "pub"))
        .collect();
    pubs.sort();
    let mut out = Vec::new();
    for p in pubs {
        let private = p.with_extension("");
        if !private.is_file() {
            continue;
        }
        if let Ok(s) = std::fs::read_to_string(&p) {
            if let Some(l) = s.lines().next() {
                if is_supported_key(l) {
                    out.push((key_id(l), private));
                }
            }
        }
    }
    out
}
fn sha256_hex(b: &[u8]) -> String {
    Sha256::digest(b).iter().map(|x| format!("{:02x}", x)).collect()
}
/// Send a request to dev-null; its answers are plain text.
fn devnull_request(req: reqwest::blocking::RequestBuilder) -> Result<String> {
    let resp = req.send().context("could not reach dev-null")?;
    let status = resp.status();
    let body = sanitize(&resp.text()?);
    if !status.is_success() {
        let b = body.trim();
        if b.is_empty() {
            bail!("unexpected answer from dev-null (HTTP {})", status.as_u16());
        }
        bail!("{b}");
    }
    Ok(body)
}
/// `ssh-keygen -Y sign` on a file in `dir`; returns the bare base64 of the armored signature.
fn ssh_sign(dir: &Path, signing_key: &Path, namespace: &str, data: &str) -> Result<String> {
    let commit = dir.join("commit");
    std::fs::write(&commit, data)?;
    let out = Command::new("ssh-keygen")
        .args(["-Y", "sign", "-n", namespace, "-f"])
        .arg(signing_key)
        .arg(&commit)
        .stdin(Stdio::null()) // passphrase prompts go to /dev/tty
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                anyhow!("`ssh-keygen` not found (OpenSSH 8.1+ is needed to sign)")
            } else {
                anyhow!("running ssh-keygen: {e}")
            }
        })?;
    if !out.status.success() {
        bail!(
            "could not sign with {}: {}",
            signing_key.display(),
            sanitize(String::from_utf8_lossy(&out.stderr).trim())
        );
    }
    let armored = std::fs::read_to_string(dir.join("commit.sig")).context("reading signature")?;
    let sig: String = armored.lines().filter(|l| !l.contains("-----")).collect::<Vec<_>>().concat();
    if sig.is_empty() || !sig.chars().all(|c| c.is_ascii_alphanumeric() || "+/=".contains(c)) {
        bail!("ssh-keygen produced an unexpected signature");
    }
    Ok(sig)
}
fn post_devnull(
    _http: &Client,
    acc: &Account,
    text: &str,
    media: &[Media],
    reply_to: Option<&str>,
) -> Result<String> {
    let base = acc.instance.as_deref().unwrap_or(DEVNULL_DEFAULT_URL).trim_end_matches('/');
    let host_is = |h: &str| base == h || base.starts_with(&format!("{h}:"));
    if !base.starts_with("https://") && !host_is("http://localhost") && !host_is("http://127.0.0.1") {
        bail!("refusing to send your commit to {base}: it is not an https:// URL");
    }
    if text.trim().is_empty() {
        bail!("aborting commit due to empty commit message");
    }
    if let Some(r) = reply_to {
        if r.is_empty() || r.chars().any(|c| !(c.is_ascii_alphanumeric() || ":/._@-".contains(c))) {
            bail!("--reply-to takes the hash of a commit or its link");
        }
    }
    if media.len() > DEVNULL_MAX_IMAGES {
        bail!("a dev-null commit can carry up to {DEVNULL_MAX_IMAGES} images");
    }
    for m in media {
        if !DEVNULL_IMAGE_MIMES.contains(&m.mime.as_str()) {
            bail!("{}: dev-null only takes JPEG, PNG or WebP images (got {})", m.name, m.mime);
        }
        if m.bytes.len() > DEVNULL_MAX_IMAGE_BYTES {
            bail!("{}: larger than 10 MB", m.name);
        }
        if m.alt.is_some() {
            eprintln!("warning: dev-null has no alt text; ignoring alt for {}", m.name);
        }
    }
    // Never follow redirects with a signed request.
    let http = Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .timeout(Duration::from_secs(30))
        .user_agent(concat!("post-script/", env!("CARGO_PKG_VERSION")))
        .build()?;
    let tmp = TmpDir::new()?;

    // 1. Which key signs: --key, or whichever local key /dev/null finds on your GitHub account.
    let signing_key: PathBuf = if let Some(k) = &acc.key {
        PathBuf::from(expand_tilde(k))
    } else {
        let agent = agent_keys();
        let disk = ssh_dir_keys();
        let mut candidates: Vec<String> = Vec::new();
        for k in agent.iter().cloned().chain(disk.iter().map(|(id, _)| id.clone())) {
            if !candidates.contains(&k) {
                candidates.push(k);
            }
        }
        if candidates.is_empty() {
            bail!("no Ed25519 or RSA SSH key found in your SSH agent or in ~/.ssh");
        }
        let list = candidates.join("\n") + "\n";
        let answer = devnull_request(
            http.post(format!("{base}/api/cli/key-lookups"))
                .header(reqwest::header::CONTENT_TYPE, "text/plain; charset=utf-8")
                .body(list),
        )?;
        let key = key_id(answer.lines().next().unwrap_or(""));
        // Only ever sign with one of our own keys, whatever the server answers.
        if !candidates.contains(&key) {
            bail!("unexpected answer from {base}");
        }
        if agent.contains(&key) {
            let p = tmp.0.join("key.pub");
            std::fs::write(&p, format!("{key}\n"))?;
            p
        } else if let Some((_, private)) = disk.iter().find(|(id, _)| *id == key) {
            private.clone()
        } else {
            bail!("could not find the private key of {key}");
        }
    };

    // 2. Sign: <timestamp>\n<nonce>\n<reply to or empty>\n[<image hashes>\n]<message>
    let ts = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs();
    let nonce = format!("{:032x}", rand::random::<u128>());
    let reply = reply_to.unwrap_or("");
    let (payload, namespace) = if media.is_empty() {
        (format!("{ts}\n{nonce}\n{reply}\n{text}"), DEVNULL_NAMESPACE)
    } else {
        let hashes = media.iter().map(|m| sha256_hex(&m.bytes)).collect::<Vec<_>>().join(",");
        (format!("{ts}\n{nonce}\n{reply}\n{hashes}\n{text}"), DEVNULL_IMAGES_NAMESPACE)
    };
    let sig = ssh_sign(&tmp.0, &signing_key, namespace, &payload)?;

    // 3. Commit: the raw payload, or a multipart form of the payload and the images.
    let req = http.post(format!("{base}/api/cli/commits")).header("X-SSH-Signature", sig);
    let req = if media.is_empty() {
        req.header(reqwest::header::CONTENT_TYPE, "text/plain; charset=utf-8").body(payload)
    } else {
        let part = |name: String, bytes: Vec<u8>| -> Result<multipart::Part> {
            Ok(multipart::Part::bytes(bytes).file_name(name).mime_str("application/octet-stream")?)
        };
        let mut form = multipart::Form::new().part("payload", part("commit".into(), payload.into_bytes())?);
        for (i, m) in media.iter().enumerate() {
            form = form.part("images[]", part(format!("image-{}", i + 1), m.bytes.clone())?);
        }
        req.multipart(form).timeout(Duration::from_secs(600))
    };
    let answer = devnull_request(req)?;
    let answer = answer.trim();
    Ok(if answer.is_empty() { "(posted)".to_string() } else { answer.to_string() })
}
// ───────────────────────────── Main flow ─────────────────────────────
fn post_one(
    http: &Client,
    name: &str,
    acc: &Account,
    text: &str,
    media: &[Media],
    vis: Visibility,
    reply_to: Option<&str>,
) -> Result<String> {
    match acc.kind {
        Kind::Mastodon => post_mastodon(http, acc, &resolve_secret(name, acc)?, text, media, vis),
        Kind::Bluesky => post_bluesky(http, acc, &resolve_secret(name, acc)?, text, media),
        // Cookies are optional: without a stored secret, twitter-cli uses the browser's.
        Kind::Twitter => post_twitter(acc, lookup_secret(name, acc)?.as_deref(), text, media),
        // Signed locally with an SSH key; no stored secret.
        Kind::Devnull => post_devnull(http, acc, text, media, reply_to),
    }
}
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
            path: p.clone(),
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
        match post_one(&http, name, acc, &body, &media, args.visibility, args.reply_to.as_deref()) {
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
