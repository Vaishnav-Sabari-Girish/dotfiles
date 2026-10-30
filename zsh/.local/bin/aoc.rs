#!/usr/bin/env rust-script
//! Advent of Code TUI solver.
//!
//! ```cargo
//! [dependencies]
//! ratatui = "*"
//! ureq = "*"
//! regex = "*"
//! chrono = "*"
//! ```
//!
//! Usage:   rust-script aoc.rs        (or chmod +x aoc.rs && ./aoc.rs)
//!
//! Settings live in the app, press S for your session cookie and L to pick your language.
//! Both are saved under the data directory, so there are no env vars to export.
//! Optional: AOC_DIR sets where puzzles/inputs/solutions live (default: ~/aoc).
//!
//! Languages: D (default, run with `dub`), C, C++, Rust, Python, or Others (your own
//! file extension and run command; {file} stands for the solution file).
//!
//! Your solution reads the puzzle input from stdin and prints the part 1 answer on the
//! first line and the part 2 answer on the second line.

use std::{
    collections::{HashMap, HashSet},
    fs,
    io,
    path::PathBuf,
    process::{Command, Stdio},
    sync::mpsc::{self, Sender},
    thread,
    time::{Duration, Instant},
};

use chrono::{Datelike, Local, TimeZone};
use ratatui::{
    crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers},
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Tabs, Wrap},
    DefaultTerminal, Frame,
};

const UA: &str = "aoc-tui (rust-script) personal use";

// ───────────────────────────── config ─────────────────────────────

struct Preset {
    name: &'static str,
    ext: &'static str,
    cmd: &'static str,
    tpl: &'static str,
}

const PRESETS: [Preset; 5] = [
    Preset { name: "D", ext: "d", cmd: "dub run --single --quiet {file}", tpl: TPL_D },
    Preset { name: "C", ext: "c", cmd: "gcc -O2 -o sol_bin {file} -lm && ./sol_bin", tpl: TPL_C },
    Preset { name: "C++", ext: "cpp", cmd: "g++ -O2 -std=c++20 -o sol_bin {file} && ./sol_bin", tpl: TPL_CPP },
    Preset { name: "Rust", ext: "rs", cmd: "rust-script {file}", tpl: TPL_RS },
    Preset { name: "Python", ext: "py", cmd: "python3 {file}", tpl: TPL_PY },
];

struct Config {
    root: PathBuf,
    lang: String,
    ext: String,
    cmd: String,
}

impl Config {
    fn load() -> Self {
        let root = std::env::var("AOC_DIR").map(PathBuf::from).unwrap_or_else(|_| {
            PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| ".".into())).join("aoc")
        });
        let mut cfg = Config {
            root,
            lang: PRESETS[0].name.into(),
            ext: PRESETS[0].ext.into(),
            cmd: PRESETS[0].cmd.into(),
        };
        if let Ok(s) = fs::read_to_string(cfg.config_file()) {
            for line in s.lines() {
                if let Some((k, v)) = line.split_once('=') {
                    let v = v.trim().to_string();
                    match k.trim() {
                        "lang" => cfg.lang = v,
                        "ext" => cfg.ext = v,
                        "cmd" => cfg.cmd = v,
                        _ => {}
                    }
                }
            }
        }
        cfg
    }
    fn config_file(&self) -> PathBuf {
        self.root.join("config")
    }
    fn save(&self) {
        let _ = fs::create_dir_all(&self.root);
        let _ = fs::write(
            self.config_file(),
            format!("lang={}\next={}\ncmd={}\n", self.lang, self.ext, self.cmd),
        );
    }
    fn set_preset(&mut self, i: usize) {
        let p = &PRESETS[i];
        self.lang = p.name.into();
        self.ext = p.ext.into();
        self.cmd = p.cmd.into();
        self.save();
    }
    fn set_custom(&mut self, ext: String, mut cmd: String) {
        if !cmd.contains("{file}") {
            cmd.push_str(" {file}");
        }
        self.lang = "Others".into();
        self.ext = ext;
        self.cmd = cmd;
        self.save();
    }
    fn template(&self) -> &'static str {
        PRESETS.iter().find(|p| p.name == self.lang).map(|p| p.tpl).unwrap_or("")
    }
    fn day_dir(&self, year: i32, day: u32) -> PathBuf {
        self.root.join(year.to_string()).join(format!("day{day:02}"))
    }
    fn session_file(&self) -> PathBuf {
        self.root.join(".session")
    }
    fn load_session(&self) -> String {
        if let Ok(s) = std::env::var("AOC_SESSION") {
            if !s.trim().is_empty() {
                return s.trim().to_string();
            }
        }
        fs::read_to_string(self.session_file()).map(|s| s.trim().to_string()).unwrap_or_default()
    }
}

const TPL_PY: &str = r#"import sys

data = sys.stdin.read()


def part1(data):
    return "TODO"


def part2(data):
    return "TODO"


print(part1(data))
print(part2(data))
"#;

const TPL_RS: &str = r#"#!/usr/bin/env rust-script
use std::io::Read;

fn part1(_input: &str) -> String {
    "TODO".into()
}

fn part2(_input: &str) -> String {
    "TODO".into()
}

fn main() {
    let mut input = String::new();
    std::io::stdin().read_to_string(&mut input).unwrap();
    println!("{}", part1(&input));
    println!("{}", part2(&input));
}
"#;

const TPL_D: &str = r#"/+ dub.sdl:
    name "solution"
+/
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;
import std.array;
import std.range;

string part1(string input)
{
    return "TODO";
}

string part2(string input)
{
    return "TODO";
}

void main()
{
    string input = stdin.byLineCopy.array.join("\n");
    writeln(part1(input));
    writeln(part2(input));
}
"#;

const TPL_C: &str = r#"#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    size_t cap = 1 << 16, len = 0, n;
    char *input = malloc(cap);
    while ((n = fread(input + len, 1, cap - len - 1, stdin)) > 0) {
        len += n;
        if (cap - len < 4096) {
            cap *= 2;
            input = realloc(input, cap);
        }
    }
    input[len] = '\0';

    printf("%s\n", "TODO"); /* part 1 */
    printf("%s\n", "TODO"); /* part 2 */

    free(input);
    return 0;
}
"#;

const TPL_CPP: &str = r#"#include <bits/stdc++.h>
using namespace std;

string part1(const string& input) { return "TODO"; }
string part2(const string& input) { return "TODO"; }

int main() {
    ios::sync_with_stdio(false);
    string input((istreambuf_iterator<char>(cin)), istreambuf_iterator<char>());
    cout << part1(input) << "\n" << part2(input) << "\n";
}
"#;

// ───────────────────────────── http ─────────────────────────────

fn err_str(e: ureq::Error) -> String {
    match e {
        ureq::Error::StatusCode(c) => format!("HTTP {c}"),
        e => e.to_string(),
    }
}

fn http_get(url: &str, session: &str) -> Result<String, String> {
    let mut req = ureq::get(url).header("User-Agent", UA);
    if !session.is_empty() {
        req = req.header("Cookie", format!("session={session}"));
    }
    let mut resp = req.call().map_err(err_str)?;
    resp.body_mut().read_to_string().map_err(err_str)
}

fn http_submit(year: i32, day: u32, level: u8, answer: &str, session: &str) -> Result<String, String> {
    let url = format!("https://adventofcode.com/{year}/day/{day}/answer");
    let lvl = level.to_string();
    let mut resp = ureq::post(&url)
        .header("User-Agent", UA)
        .header("Cookie", format!("session={session}"))
        .send_form([("level", lvl.as_str()), ("answer", answer)])
        .map_err(err_str)?;
    let body = resp.body_mut().read_to_string().map_err(err_str)?;
    let main = regex::Regex::new(r"(?s)<main>(.*?)</main>")
        .unwrap()
        .captures(&body)
        .map(|c| c[1].to_string())
        .unwrap_or(body);
    let text = regex::Regex::new(r"<[^>]+>").unwrap().replace_all(&main, " ").to_string();
    let text = decode(&text).split_whitespace().collect::<Vec<_>>().join(" ");
    Ok(match text.find("[Return") {
        Some(i) => text[..i].trim().to_string(),
        None => text,
    })
}

fn parse_stars(html: &str) -> HashMap<u32, u8> {
    let re = regex::Regex::new(r#"aria-label="Day (\d+)(?:, (one|two) stars?)?""#).unwrap();
    let mut m = HashMap::new();
    for c in re.captures_iter(html) {
        let d: u32 = c[1].parse().unwrap_or(0);
        let s = match c.get(2).map(|x| x.as_str()) {
            Some("one") => 1,
            Some("two") => 2,
            _ => 0,
        };
        m.insert(d, s);
    }
    m
}

fn extract(html: &str) -> String {
    let re = regex::Regex::new(r#"(?s)<article class="day-desc">(.*?)</article>"#).unwrap();
    let parts: Vec<String> = re.captures_iter(html).map(|c| c[1].to_string()).collect();
    if parts.is_empty() {
        "<p>(no puzzle text found on that page)</p>".into()
    } else {
        parts.join("\n")
    }
}

// ───────────────────────── html → styled lines ─────────────────────────

fn decode(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    let mut rest = s;
    while let Some(i) = rest.find('&') {
        o.push_str(&rest[..i]);
        rest = &rest[i..];
        if let Some(j) = rest.find(';').filter(|&j| j <= 8) {
            let ent = &rest[1..j];
            let rep: Option<String> = match ent {
                "lt" => Some("<".into()),
                "gt" => Some(">".into()),
                "amp" => Some("&".into()),
                "quot" => Some("\"".into()),
                "apos" => Some("'".into()),
                "nbsp" => Some(" ".into()),
                e if e.starts_with('#') => {
                    let n = match e.strip_prefix("#x") {
                        Some(h) => u32::from_str_radix(h, 16).ok(),
                        None => e[1..].parse().ok(),
                    };
                    n.and_then(char::from_u32).map(|c| c.to_string())
                }
                _ => None,
            };
            if let Some(r) = rep {
                o.push_str(&r);
                rest = &rest[j + 1..];
                continue;
            }
        }
        o.push('&');
        rest = &rest[1..];
    }
    o.push_str(rest);
    o
}

fn wrap(segs: &[(String, Style)], width: usize) -> Vec<Line<'static>> {
    let width = width.max(10);
    let mut lines = vec![];
    let mut cur: Vec<Span<'static>> = vec![];
    let mut w = 0usize;
    for (t, st) in segs {
        for word in t.split_inclusive(' ') {
            let len = word.chars().count();
            let trimmed = word.trim_end().chars().count();
            if w > 0 && w + trimmed > width {
                lines.push(Line::from(std::mem::take(&mut cur)));
                w = 0;
            }
            if word.trim().is_empty() {
                let last_space = cur.last().map(|s| s.content.ends_with(' ')).unwrap_or(true);
                if w == 0 || last_space {
                    continue;
                }
            }
            cur.push(Span::styled(word.to_string(), *st));
            w += len;
        }
    }
    if !cur.is_empty() {
        lines.push(Line::from(cur));
    }
    lines
}

struct R {
    width: usize,
    out: Vec<Line<'static>>,
    segs: Vec<(String, Style)>,
    em: u32,
    code: u32,
    link: u32,
    pre: bool,
    heading: bool,
}

impl R {
    fn style(&self) -> Style {
        let mut s = Style::default();
        if self.heading {
            s = s.fg(Color::Cyan).add_modifier(Modifier::BOLD);
        }
        if self.code > 0 {
            s = s.fg(Color::Green);
        }
        if self.link > 0 {
            s = s.fg(Color::Blue).add_modifier(Modifier::UNDERLINED);
        }
        if self.em > 0 {
            s = s
                .fg(if self.code > 0 { Color::White } else { Color::Yellow })
                .add_modifier(Modifier::BOLD);
        }
        s
    }

    fn blank(&mut self) {
        if self.out.last().map(|l| !l.spans.is_empty()).unwrap_or(false) {
            self.out.push(Line::default());
        }
    }

    fn text(&mut self, t: &str) {
        let t = decode(t);
        let st = self.style();
        if self.pre {
            self.segs.push((t, st));
            return;
        }
        let mut s = String::new();
        let mut prev_ws = false;
        for c in t.chars() {
            if c.is_whitespace() {
                if !prev_ws {
                    s.push(' ');
                }
                prev_ws = true;
            } else {
                s.push(c);
                prev_ws = false;
            }
        }
        if s.trim().is_empty() && self.segs.is_empty() {
            return;
        }
        self.segs.push((s, st));
    }

    fn flush(&mut self) {
        if self.segs.is_empty() {
            return;
        }
        let segs = std::mem::take(&mut self.segs);
        if self.pre {
            let mut cur: Vec<Span<'static>> = vec![Span::raw("  ")];
            for (t, st) in segs {
                let mut parts = t.split('\n').peekable();
                while let Some(p) = parts.next() {
                    if !p.is_empty() {
                        cur.push(Span::styled(p.to_string(), st));
                    }
                    if parts.peek().is_some() {
                        self.out.push(Line::from(std::mem::replace(&mut cur, vec![Span::raw("  ")])));
                    }
                }
            }
            if cur.len() > 1 {
                self.out.push(Line::from(cur));
            }
        } else {
            let l = wrap(&segs, self.width);
            self.out.extend(l);
        }
    }

    fn tag(&mut self, raw: &str) {
        let closing = raw.starts_with('/');
        let name = raw
            .trim_start_matches('/')
            .split(|c: char| c.is_whitespace() || c == '/')
            .next()
            .unwrap_or("")
            .to_lowercase();
        let upd = |n: &mut u32| {
            if closing {
                *n = n.saturating_sub(1)
            } else {
                *n += 1
            }
        };
        match (name.as_str(), closing) {
            ("h2", false) => {
                self.flush();
                self.heading = true;
            }
            ("h2", true) => {
                self.flush();
                self.heading = false;
                self.blank();
            }
            ("p", false) | ("article", _) | ("br", _) | ("li", true) => self.flush(),
            ("p", true) | ("ul", true) | ("ol", true) => {
                self.flush();
                self.blank();
            }
            ("pre", false) => {
                self.flush();
                self.pre = true;
            }
            ("pre", true) => {
                self.flush();
                self.pre = false;
                self.blank();
            }
            ("li", false) => {
                self.flush();
                let st = self.style();
                self.segs.push(("• ".into(), st));
            }
            ("em", _) | ("strong", _) => upd(&mut self.em),
            ("code", _) => upd(&mut self.code),
            ("a", _) => upd(&mut self.link),
            _ => {}
        }
    }
}

fn render_html(html: &str, width: usize) -> Vec<Line<'static>> {
    let mut r = R {
        width,
        out: vec![],
        segs: vec![],
        em: 0,
        code: 0,
        link: 0,
        pre: false,
        heading: false,
    };
    let mut rest = html;
    while let Some(i) = rest.find('<') {
        if i > 0 {
            r.text(&rest[..i]);
        }
        rest = &rest[i..];
        if rest.starts_with("<!--") {
            match rest.find("-->") {
                Some(j) => {
                    rest = &rest[j + 3..];
                    continue;
                }
                None => {
                    rest = "";
                    break;
                }
            }
        }
        match rest.find('>') {
            Some(j) => {
                r.tag(&rest[1..j]);
                rest = &rest[j + 1..];
            }
            None => {
                rest = "";
                break;
            }
        }
    }
    if !rest.is_empty() {
        r.text(rest);
    }
    r.flush();
    r.out
}

// ───────────────────────────── app ─────────────────────────────

#[derive(PartialEq, Clone, Copy)]
enum Pane {
    Years,
    Days,
}

#[derive(PartialEq, Clone, Copy)]
enum Tab {
    Puzzle = 0,
    Input = 1,
    Output = 2,
}

fn tab_from(i: usize) -> Tab {
    match i % 3 {
        0 => Tab::Puzzle,
        1 => Tab::Input,
        _ => Tab::Output,
    }
}

#[derive(Clone)]
enum Prompt {
    Session,
    Submit(u8),
    CustomExt,
    CustomCmd(String),
}

enum Mode {
    Normal,
    Prompt { kind: Prompt, buf: String },
    Popup(String),
    Lang(usize),
}

struct View {
    year: i32,
    day: u32,
    desc: Option<String>,
    input: Option<String>,
    output: Option<String>,
    answers: Vec<String>,
    tab: Tab,
    scroll: [usize; 3],
}

struct RunResult {
    cmd: String,
    code: Option<i32>,
    stdout: String,
    stderr: String,
    elapsed: Duration,
}

impl RunResult {
    fn render(&self) -> String {
        format!(
            "$ {}\nexit: {}   time: {:.2?}\n\n--- stdout ---\n{}\n--- stderr ---\n{}",
            self.cmd,
            self.code.map(|c| c.to_string()).unwrap_or_else(|| "signal".into()),
            self.elapsed,
            self.stdout.trim_end(),
            self.stderr.trim_end()
        )
    }
}

enum Msg {
    Stars(i32, Result<HashMap<u32, u8>, String>),
    Puzzle(i32, u32, Result<String, String>),
    Input(i32, u32, Result<String, String>),
    Run(Result<RunResult, String>),
    Submit(i32, u32, Result<String, String>),
}

fn days_in(year: i32) -> u32 {
    if year >= 2025 {
        12
    } else {
        25
    }
}

/// "It opens on December 1 at midnight, in 31 days."
fn opens_text(year: i32) -> String {
    let Some(t) = Local.with_ymd_and_hms(year, 12, 1, 0, 0, 0).earliest() else {
        return "It opens on December 1 at midnight.".into();
    };
    let days = (t - Local::now()).num_days().max(0);
    format!("It opens on December 1 at midnight, in {days} days.")
}

struct App {
    cfg: Config,
    session: String,
    tx: Sender<Msg>,
    now: (i32, u32, u32),
    years: Vec<i32>,
    year_state: ListState,
    day_state: ListState,
    pane: Pane,
    stars: HashMap<i32, HashMap<u32, u8>>,
    stars_req: HashSet<i32>,
    view: Option<View>,
    mode: Mode,
    status: String,
    edit: Option<PathBuf>,
    running: bool,
    quit: bool,
    page: usize,
}

impl App {
    fn new(tx: Sender<Msg>) -> Self {
        let cfg = Config::load();
        let today = Local::now().date_naive();
        let now = (today.year(), today.month(), today.day());
        let years: Vec<i32> = (2015..=now.0).rev().collect();
        let in_season = now.1 == 12;
        let mut year_state = ListState::default();
        // Land on the newest year that has actually started.
        year_state.select(Some(if in_season { 0 } else { 1.min(years.len() - 1) }));
        let mut day_state = ListState::default();
        let d = if in_season { now.2.min(days_in(now.0)) } else { 1 };
        day_state.select(Some(d as usize - 1));
        let session = cfg.load_session();
        let status = if session.is_empty() {
            "No session cookie — press S to paste yours (or export AOC_SESSION)".into()
        } else {
            "Ready".into()
        };
        let mut app = App {
            cfg,
            session,
            tx,
            now,
            years,
            year_state,
            day_state,
            pane: Pane::Days,
            stars: HashMap::new(),
            stars_req: HashSet::new(),
            view: None,
            mode: Mode::Normal,
            status,
            edit: None,
            running: false,
            quit: false,
            page: 10,
        };
        app.ensure_stars();
        app
    }

    fn year(&self) -> i32 {
        self.years[self.year_state.selected().unwrap_or(0)]
    }
    fn day(&self) -> u32 {
        self.day_state.selected().unwrap_or(0) as u32 + 1
    }
    fn started(&self, y: i32) -> bool {
        y < self.now.0 || (y == self.now.0 && self.now.1 == 12)
    }
    fn unlocked(&self, y: i32, d: u32) -> bool {
        let (cy, cm, cd) = self.now;
        y < cy || (y == cy && cm == 12 && d <= cd)
    }

    // ── background work ──
    fn ensure_stars(&mut self) {
        let y = self.year();
        self.fetch_stars(y);
    }
    fn fetch_stars(&mut self, y: i32) {
        if self.session.is_empty() || !self.started(y) || !self.stars_req.insert(y) {
            return;
        }
        let (tx, s) = (self.tx.clone(), self.session.clone());
        thread::spawn(move || {
            let r = http_get(&format!("https://adventofcode.com/{y}"), &s).map(|h| parse_stars(&h));
            let _ = tx.send(Msg::Stars(y, r));
        });
    }
    fn fetch_puzzle(&self, y: i32, d: u32) {
        let (tx, s) = (self.tx.clone(), self.session.clone());
        thread::spawn(move || {
            let r = http_get(&format!("https://adventofcode.com/{y}/day/{d}"), &s);
            let _ = tx.send(Msg::Puzzle(y, d, r));
        });
    }
    fn fetch_input(&mut self, y: i32, d: u32) {
        if self.session.is_empty() {
            self.status = "Need a session cookie to download your input — press S".into();
            return;
        }
        let (tx, s) = (self.tx.clone(), self.session.clone());
        thread::spawn(move || {
            let r = http_get(&format!("https://adventofcode.com/{y}/day/{d}/input"), &s);
            let _ = tx.send(Msg::Input(y, d, r));
        });
    }

    fn on_msg(&mut self, m: Msg) {
        match m {
            Msg::Stars(y, r) => match r {
                Ok(map) => {
                    self.stars.insert(y, map);
                }
                Err(e) => {
                    self.stars_req.remove(&y);
                    self.status = format!("Couldn't load stars for {y}: {e}");
                }
            },
            Msg::Puzzle(y, d, r) => match r {
                Ok(html) => {
                    let dir = self.cfg.day_dir(y, d);
                    let _ = fs::create_dir_all(&dir);
                    let _ = fs::write(dir.join("puzzle.html"), &html);
                    if let Some(v) = &mut self.view {
                        if v.year == y && v.day == d {
                            v.desc = Some(extract(&html));
                        }
                    }
                    self.status = format!("Puzzle {y} day {d} loaded");
                }
                Err(e) => self.status = format!("Puzzle download failed: {e}"),
            },
            Msg::Input(y, d, r) => match r {
                Ok(text) => {
                    let dir = self.cfg.day_dir(y, d);
                    let _ = fs::create_dir_all(&dir);
                    let _ = fs::write(dir.join("input.txt"), &text);
                    if let Some(v) = &mut self.view {
                        if v.year == y && v.day == d {
                            v.input = Some(text);
                        }
                    }
                    self.status = format!("Input {y} day {d} downloaded");
                }
                Err(e) => self.status = format!("Input download failed: {e}"),
            },
            Msg::Run(r) => {
                self.running = false;
                match r {
                    Ok(rr) => {
                        if let Some(v) = &mut self.view {
                            v.answers = rr
                                .stdout
                                .lines()
                                .map(|l| l.trim().to_string())
                                .filter(|l| !l.is_empty())
                                .take(2)
                                .collect();
                            v.output = Some(rr.render());
                            v.tab = Tab::Output;
                            v.scroll[2] = 0;
                        }
                        self.status = format!("Finished in {:.2?} — press 1 / 2 to submit part 1 / 2", rr.elapsed);
                    }
                    Err(e) => self.status = format!("Run failed: {e}"),
                }
            }
            Msg::Submit(y, d, r) => match r {
                Ok(text) => {
                    let ok = text.contains("the right answer") && !text.contains("not the right");
                    self.mode = Mode::Popup(text);
                    if ok {
                        self.stars_req.remove(&y);
                        self.fetch_stars(y);
                        self.fetch_puzzle(y, d);
                    }
                }
                Err(e) => self.status = format!("Submit failed: {e}"),
            },
        }
    }

    // ── navigation ──
    fn open_day(&mut self, y: i32, d: u32) {
        if !self.started(y) {
            self.status = format!("Advent of Code {y} hasn't started yet. {}", opens_text(y));
            return;
        }
        if !self.unlocked(y, d) {
            self.status = format!("{y} day {d} isn't unlocked yet");
            return;
        }
        let dir = self.cfg.day_dir(y, d);
        let desc = fs::read_to_string(dir.join("puzzle.html")).ok().map(|h| extract(&h));
        let input = fs::read_to_string(dir.join("input.txt")).ok();
        let need_puzzle = desc.is_none();
        let need_input = input.is_none();
        self.view = Some(View {
            year: y,
            day: d,
            desc,
            input,
            output: None,
            answers: vec![],
            tab: Tab::Puzzle,
            scroll: [0; 3],
        });
        if need_puzzle {
            self.status = "Downloading puzzle…".into();
            self.fetch_puzzle(y, d);
        } else {
            self.status = format!("{y} day {d} (cached — press R to refresh)");
        }
        if need_input {
            self.fetch_input(y, d);
        }
    }

    fn move_sel(&mut self, delta: i32) {
        match self.pane {
            Pane::Years => {
                let n = self.years.len() as i32;
                let i = self.year_state.selected().unwrap_or(0) as i32;
                self.year_state.select(Some((i + delta).clamp(0, n - 1) as usize));
                let nd = days_in(self.year());
                if self.day() > nd {
                    self.day_state.select(Some(nd as usize - 1));
                }
                self.ensure_stars();
            }
            Pane::Days => {
                let n = days_in(self.year()) as i32;
                let i = self.day_state.selected().unwrap_or(0) as i32;
                self.day_state.select(Some((i + delta).clamp(0, n - 1) as usize));
            }
        }
    }

    fn on_key(&mut self, k: KeyEvent) {
        if k.kind != KeyEventKind::Press {
            return;
        }
        if k.modifiers.contains(KeyModifiers::CONTROL) && k.code == KeyCode::Char('c') {
            self.quit = true;
            return;
        }
        if matches!(self.mode, Mode::Popup(_)) {
            self.mode = Mode::Normal;
            return;
        }
        if let Mode::Lang(i) = &mut self.mode {
            match k.code {
                KeyCode::Up | KeyCode::Char('k') => *i = i.saturating_sub(1),
                KeyCode::Down | KeyCode::Char('j') => *i = (*i + 1).min(PRESETS.len()),
                KeyCode::Esc | KeyCode::Char('q') => self.mode = Mode::Normal,
                KeyCode::Enter => {
                    let sel = *i;
                    self.mode = Mode::Normal;
                    self.choose_lang(sel);
                }
                KeyCode::Char(c @ '1'..='6') => {
                    self.mode = Mode::Normal;
                    self.choose_lang(c as usize - '1' as usize);
                }
                _ => {}
            }
            return;
        }
        if let Mode::Prompt { kind, buf } = &mut self.mode {
            match k.code {
                KeyCode::Char(c) => buf.push(c),
                KeyCode::Backspace => {
                    buf.pop();
                }
                KeyCode::Esc => self.mode = Mode::Normal,
                KeyCode::Enter => {
                    let b = buf.clone();
                    let kd = kind.clone();
                    self.mode = Mode::Normal;
                    self.finish_prompt(kd, b);
                }
                _ => {}
            }
            return;
        }
        if self.view.is_some() {
            self.puzzle_key(k);
        } else {
            self.picker_key(k);
        }
    }

    fn picker_key(&mut self, k: KeyEvent) {
        match k.code {
            KeyCode::Char('q') | KeyCode::Esc => self.quit = true,
            KeyCode::Char('L') => self.open_lang(),
            KeyCode::Up | KeyCode::Char('k') => self.move_sel(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_sel(1),
            KeyCode::PageUp => self.move_sel(-5),
            KeyCode::PageDown => self.move_sel(5),
            KeyCode::Left | KeyCode::Char('h') => self.pane = Pane::Years,
            KeyCode::Right | KeyCode::Char('l') => self.pane = Pane::Days,
            KeyCode::Tab => {
                self.pane = if self.pane == Pane::Years { Pane::Days } else { Pane::Years }
            }
            KeyCode::Enter => match self.pane {
                Pane::Years => self.pane = Pane::Days,
                Pane::Days => {
                    let (y, d) = (self.year(), self.day());
                    self.open_day(y, d);
                }
            },
            KeyCode::Char('S') => {
                self.mode = Mode::Prompt { kind: Prompt::Session, buf: String::new() }
            }
            _ => {}
        }
    }

    fn scroll(&mut self, delta: i64) {
        if let Some(v) = &mut self.view {
            let t = v.tab as usize;
            v.scroll[t] = if delta < 0 {
                v.scroll[t].saturating_sub((-delta) as usize)
            } else {
                v.scroll[t].saturating_add(delta as usize)
            };
        }
    }

    fn set_tab(&mut self, t: Tab) {
        if let Some(v) = &mut self.view {
            v.tab = t;
        }
    }

    fn cycle_tab(&mut self, d: i32) {
        if let Some(v) = &mut self.view {
            v.tab = tab_from((v.tab as i32 + d + 3) as usize);
        }
    }

    fn puzzle_key(&mut self, k: KeyEvent) {
        let page = self.page.max(1) as i64;
        let ctrl = k.modifiers.contains(KeyModifiers::CONTROL);
        match k.code {
            KeyCode::Char('d') if ctrl => self.scroll(page / 2),
            KeyCode::Char('u') if ctrl => self.scroll(-page / 2),
            KeyCode::Esc | KeyCode::Backspace | KeyCode::Char('q') => self.view = None,
            KeyCode::Char('p') => self.set_tab(Tab::Puzzle),
            KeyCode::Char('i') => self.set_tab(Tab::Input),
            KeyCode::Char('o') => self.set_tab(Tab::Output),
            KeyCode::Tab | KeyCode::Right | KeyCode::Char('l') => self.cycle_tab(1),
            KeyCode::BackTab | KeyCode::Left | KeyCode::Char('h') => self.cycle_tab(-1),
            KeyCode::Down | KeyCode::Char('j') => self.scroll(1),
            KeyCode::Up | KeyCode::Char('k') => self.scroll(-1),
            KeyCode::PageDown | KeyCode::Char(' ') => self.scroll(page),
            KeyCode::PageUp => self.scroll(-page),
            KeyCode::Home | KeyCode::Char('g') => self.scroll(i64::MIN / 2),
            KeyCode::End | KeyCode::Char('G') => self.scroll(i64::MAX / 2),
            KeyCode::Char('e') => self.start_edit(),
            KeyCode::Char('L') => self.open_lang(),
            KeyCode::Char('r') => self.start_run(),
            KeyCode::Char('1') => self.start_submit(1),
            KeyCode::Char('2') => self.start_submit(2),
            KeyCode::Char('S') => {
                self.mode = Mode::Prompt { kind: Prompt::Session, buf: String::new() }
            }
            KeyCode::Char('R') => {
                if let Some(v) = &self.view {
                    let (y, d) = (v.year, v.day);
                    self.status = "Refreshing puzzle…".into();
                    self.fetch_puzzle(y, d);
                    self.stars_req.remove(&y);
                    self.fetch_stars(y);
                }
            }
            KeyCode::Char(']') => {
                if let Some(v) = &self.view {
                    let (y, d) = (v.year, v.day);
                    if d < days_in(y) {
                        self.open_day(y, d + 1);
                    }
                }
            }
            KeyCode::Char('[') => {
                if let Some(v) = &self.view {
                    let (y, d) = (v.year, v.day);
                    if d > 1 {
                        self.open_day(y, d - 1);
                    }
                }
            }
            _ => {}
        }
    }

    fn open_lang(&mut self) {
        let i = PRESETS.iter().position(|p| p.name == self.cfg.lang).unwrap_or(PRESETS.len());
        self.mode = Mode::Lang(i);
    }

    fn choose_lang(&mut self, i: usize) {
        if i < PRESETS.len() {
            self.cfg.set_preset(i);
            self.status = format!("Language set to {} (saved) — solutions use .{}", self.cfg.lang, self.cfg.ext);
        } else {
            self.mode = Mode::Prompt { kind: Prompt::CustomExt, buf: String::new() };
        }
    }

    fn start_edit(&mut self) {
        let Some(v) = &self.view else { return };
        let dir = self.cfg.day_dir(v.year, v.day);
        let _ = fs::create_dir_all(&dir);
        let p = dir.join(format!("solution.{}", self.cfg.ext));
        if !p.exists() {
            let _ = fs::write(&p, self.cfg.template());
        }
        self.edit = Some(p);
    }

    fn start_run(&mut self) {
        if self.running {
            return;
        }
        let Some(v) = &self.view else { return };
        let dir = self.cfg.day_dir(v.year, v.day);
        let sol = format!("solution.{}", self.cfg.ext);
        let input = dir.join("input.txt");
        if !dir.join(&sol).exists() {
            self.status = "No solution file yet — press e to create and edit one".into();
            return;
        }
        if self.cfg.cmd.is_empty() {
            self.status = "No run command set — press L to choose a language".into();
            return;
        }
        if !input.exists() {
            self.status = "Input hasn't been downloaded yet".into();
            return;
        }
        self.running = true;
        self.status = "Running…".into();
        let tx = self.tx.clone();
        let cmd = self.cfg.cmd.replace("{file}", &sol);
        thread::spawn(move || {
            let t = Instant::now();
            let res = (|| -> Result<RunResult, String> {
                let f = fs::File::open(&input).map_err(|e| e.to_string())?;
                let out = Command::new("sh")
                    .arg("-c")
                    .arg(&cmd)
                    .current_dir(&dir)
                    .stdin(Stdio::from(f))
                    .output()
                    .map_err(|e| e.to_string())?;
                Ok(RunResult {
                    cmd: cmd.clone(),
                    code: out.status.code(),
                    stdout: String::from_utf8_lossy(&out.stdout).into(),
                    stderr: String::from_utf8_lossy(&out.stderr).into(),
                    elapsed: t.elapsed(),
                })
            })();
            let _ = tx.send(Msg::Run(res));
        });
    }

    fn start_submit(&mut self, level: u8) {
        let Some(v) = &self.view else { return };
        if self.session.is_empty() {
            self.status = "Need a session cookie to submit — press S".into();
            return;
        }
        let buf = v.answers.get(level as usize - 1).cloned().unwrap_or_default();
        self.mode = Mode::Prompt { kind: Prompt::Submit(level), buf };
    }

    fn finish_prompt(&mut self, kind: Prompt, buf: String) {
        let buf = buf.trim().to_string();
        match kind {
            Prompt::Session => {
                if buf.is_empty() {
                    return;
                }
                let _ = fs::create_dir_all(&self.cfg.root);
                let _ = fs::write(self.cfg.session_file(), &buf);
                self.session = buf;
                self.stars_req.clear();
                self.ensure_stars();
                self.status = "Session saved".into();
            }
            Prompt::CustomExt => {
                let ext = buf.trim_start_matches('.').to_string();
                if ext.is_empty() {
                    return;
                }
                self.mode = Mode::Prompt { kind: Prompt::CustomCmd(ext), buf: String::new() };
            }
            Prompt::CustomCmd(ext) => {
                if buf.is_empty() {
                    return;
                }
                self.cfg.set_custom(ext, buf);
                self.status = format!("Language set to Others (.{}) — saved", self.cfg.ext);
            }
            Prompt::Submit(level) => {
                if buf.is_empty() {
                    return;
                }
                let Some(v) = &self.view else { return };
                let (y, d) = (v.year, v.day);
                let (tx, s) = (self.tx.clone(), self.session.clone());
                self.status = format!("Submitting part {level}…");
                thread::spawn(move || {
                    let r = http_submit(y, d, level, &buf, &s);
                    let _ = tx.send(Msg::Submit(y, d, r));
                });
            }
        }
    }
}

// ───────────────────────────── ui ─────────────────────────────

fn centered(area: Rect, pw: u16, ph: u16) -> Rect {
    let w = area.width * pw / 100;
    let h = (area.height * ph / 100).max(3);
    Rect::new(area.x + (area.width - w) / 2, area.y + (area.height - h) / 2, w, h)
}

fn ui(f: &mut Frame, app: &mut App) {
    let [title, body, footer] =
        Layout::vertical([Constraint::Length(1), Constraint::Min(3), Constraint::Length(2)]).areas(f.area());

    f.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(" ★ Advent of Code ", Style::new().fg(Color::Green).add_modifier(Modifier::BOLD)),
            Span::styled(
                format!(" lang: {} (.{}) ", app.cfg.lang, app.cfg.ext),
                Style::new().fg(Color::Magenta),
            ),
            Span::styled(
                format!(" data: {}  ", app.cfg.root.display()),
                Style::new().fg(Color::DarkGray),
            ),
        ])),
        title,
    );

    if app.view.is_some() {
        draw_day(f, app, body);
    } else {
        draw_picker(f, app, body);
    }

    let hints = if app.view.is_some() {
        "q back · p/i/o tabs · j/k scroll · e edit · r run · 1/2 submit · R refresh · [ ] prev/next day · L language · S session"
    } else {
        "↑↓ move · ←→/Tab switch pane · Enter open · L language · S session cookie · q quit"
    };
    f.render_widget(
        Paragraph::new(vec![
            Line::from(Span::styled(app.status.clone(), Style::new().fg(Color::Yellow))),
            Line::from(Span::styled(hints, Style::new().fg(Color::DarkGray))),
        ]),
        footer,
    );

    match &app.mode {
        Mode::Normal => {}
        Mode::Lang(sel) => {
            let a = f.area();
            let w = 78.min(a.width);
            let h = 10.min(a.height);
            let r = Rect::new(a.x + (a.width - w) / 2, a.y + (a.height - h) / 2, w, h);
            let mut items: Vec<ListItem> = PRESETS
                .iter()
                .enumerate()
                .map(|(i, p)| {
                    let cur = if p.name == app.cfg.lang { " ✔" } else { "" };
                    let def = if i == 0 { " (Default)" } else { "" };
                    ListItem::new(format!("{}. {}{}{}   {}", i + 1, p.name, def, cur, p.cmd))
                })
                .collect();
            let cur = if app.cfg.lang == "Others" { " ✔" } else { "" };
            items.push(ListItem::new(format!(
                "{}. Others{}   (your own file extension + run command)",
                PRESETS.len() + 1,
                cur
            )));
            let mut st = ListState::default();
            st.select(Some(*sel));
            f.render_widget(Clear, r);
            f.render_stateful_widget(
                List::new(items)
                    .block(
                        Block::default()
                            .borders(Borders::ALL)
                            .title(" Language — Enter/1-6 to choose, Esc to cancel "),
                    )
                    .highlight_style(Style::new().add_modifier(Modifier::REVERSED))
                    .highlight_symbol("▶ "),
                r,
                &mut st,
            );
        }
        Mode::Popup(text) => {
            let r = centered(f.area(), 70, 30);
            f.render_widget(Clear, r);
            f.render_widget(
                Paragraph::new(text.clone())
                    .wrap(Wrap { trim: true })
                    .block(Block::default().borders(Borders::ALL).title(" Result — press any key ")),
                r,
            );
        }
        Mode::Prompt { kind, buf } => {
            let title = match kind {
                Prompt::Session => " Paste your adventofcode.com session cookie (Enter to save, Esc to cancel) ".to_string(),
                Prompt::Submit(l) => format!(" Submit answer for part {l} (Enter to send, Esc to cancel) "),
                Prompt::CustomExt => " File extension for your language, e.g. go, zig, kt (Enter) ".to_string(),
                Prompt::CustomCmd(ext) => format!(" Command to run solution.{ext}, use {{file}} for the file, e.g. go run {{file}} (Enter) "),
            };
            let r = centered(f.area(), 80, 10);
            let r = Rect { height: 3, ..r };
            f.render_widget(Clear, r);
            f.render_widget(
                Paragraph::new(format!("{buf}█")).block(Block::default().borders(Borders::ALL).title(title)),
                r,
            );
        }
    }
}

fn draw_picker(f: &mut Frame, app: &mut App, area: Rect) {
    let [l, r] = Layout::horizontal([Constraint::Length(20), Constraint::Min(24)]).areas(area);
    let focus = |p: Pane| {
        if app.pane == p {
            Color::Yellow
        } else {
            Color::DarkGray
        }
    };
    let (yc, dc) = (focus(Pane::Years), focus(Pane::Days));
    let y = app.year();

    let year_items: Vec<ListItem> = app
        .years
        .iter()
        .map(|y| {
            let s = app.stars.get(y).map(|m| m.values().map(|&v| v as u32).sum::<u32>());
            ListItem::new(match s {
                Some(n) => format!("{y}  ★ {n}"),
                None if !app.started(*y) => format!("{y}  (soon)"),
                None => format!("{y}"),
            })
        })
        .collect();

    let m = app.stars.get(&y);
    let day_items: Vec<ListItem> = (1..=days_in(y))
        .map(|d| {
            let st = m.and_then(|m| m.get(&d)).copied().unwrap_or(0) as usize;
            let locked = !app.unlocked(y, d);
            let mut spans = vec![Span::raw(format!("Day {d:>2}  "))];
            spans.push(Span::styled("★".repeat(st), Style::new().fg(Color::Yellow)));
            if st < 2 && !locked {
                spans.push(Span::styled("☆".repeat(2 - st), Style::new().fg(Color::DarkGray)));
            }
            if locked {
                spans.push(Span::raw("locked"));
                return ListItem::new(Line::from(spans)).style(Style::new().fg(Color::DarkGray));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();

    let hl = Style::new().add_modifier(Modifier::REVERSED);
    f.render_stateful_widget(
        List::new(year_items)
            .block(Block::default().borders(Borders::ALL).title(" Years ").border_style(Style::new().fg(yc)))
            .highlight_style(hl)
            .highlight_symbol("▶ "),
        l,
        &mut app.year_state,
    );
    let day_block = Block::default()
        .borders(Borders::ALL)
        .title(format!(" {y} "))
        .border_style(Style::new().fg(dc));
    if !app.started(y) {
        f.render_widget(
            Paragraph::new(vec![
                Line::from(""),
                Line::from(Span::styled(
                    format!("  Advent of Code {y} has not started yet."),
                    Style::new().fg(Color::Yellow).add_modifier(Modifier::BOLD),
                )),
                Line::from(""),
                Line::from(format!("  {}", opens_text(y))),
                Line::from(""),
                Line::from(Span::styled(
                    "  Pick an earlier year in the Years list to start solving.",
                    Style::new().fg(Color::DarkGray),
                )),
            ])
            .wrap(Wrap { trim: false })
            .block(day_block),
            r,
        );
    } else {
        f.render_stateful_widget(
            List::new(day_items).block(day_block).highlight_style(hl).highlight_symbol("▶ "),
            r,
            &mut app.day_state,
        );
    }
}

fn draw_day(f: &mut Frame, app: &mut App, area: Rect) {
    let [tabs_a, body_a] = Layout::vertical([Constraint::Length(1), Constraint::Min(3)]).areas(area);
    let (tab, year, day) = {
        let v = app.view.as_ref().unwrap();
        (v.tab, v.year, v.day)
    };
    f.render_widget(
        Tabs::new(vec!["Puzzle (p)", "Input (i)", "Output (o)"])
            .select(tab as usize)
            .highlight_style(Style::new().fg(Color::Yellow).add_modifier(Modifier::BOLD))
            .divider("│"),
        tabs_a,
    );
    let block = Block::default().borders(Borders::ALL).title(format!(" {year} · Day {day} "));
    let inner = block.inner(body_a);
    let (w, h) = (inner.width as usize, inner.height as usize);
    app.page = h;

    let (lines, total, sc, pscroll): (Vec<Line<'static>>, usize, usize, u16) = {
        let v = app.view.as_ref().unwrap();
        let want = v.scroll[tab as usize];
        match tab {
            Tab::Puzzle => match &v.desc {
                Some(d) => {
                    let l = render_html(d, w.saturating_sub(2));
                    let n = l.len();
                    let sc = want.min(n.saturating_sub(h));
                    (l, n, sc, sc as u16)
                }
                None => (vec![Line::from("Loading puzzle…")], 1, 0, 0),
            },
            Tab::Input => match &v.input {
                Some(s) => {
                    let n = s.lines().count();
                    let sc = want.min(n.saturating_sub(h));
                    let l = s.lines().skip(sc).take(h).map(|l| Line::from(l.to_string())).collect();
                    (l, n, sc, 0)
                }
                None => (vec![Line::from("No input yet (needs a session cookie — press S)")], 1, 0, 0),
            },
            Tab::Output => match &v.output {
                Some(s) => {
                    let all: Vec<Line<'static>> = s.lines().map(|l| Line::from(l.to_string())).collect();
                    let n = all.len();
                    let sc = want.min(n.saturating_sub(h));
                    (all, n, sc, sc as u16)
                }
                None => (vec![Line::from("Nothing run yet — press e to write a solution, r to run it")], 1, 0, 0),
            },
        }
    };
    app.view.as_mut().unwrap().scroll[tab as usize] = sc;
    let block = block.title_bottom(format!(" {}/{} ", (sc + 1).min(total), total));
    f.render_widget(Paragraph::new(lines).block(block).scroll((pscroll, 0)), body_a);
}

// ───────────────────────────── main ─────────────────────────────

fn run(term: &mut DefaultTerminal) -> io::Result<()> {
    let (tx, rx) = mpsc::channel();
    let mut app = App::new(tx);
    loop {
        while let Ok(m) = rx.try_recv() {
            app.on_msg(m);
        }
        term.draw(|f| ui(f, &mut app))?;
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(k) = event::read()? {
                app.on_key(k);
            }
        }
        if let Some(path) = app.edit.take() {
            ratatui::restore();
            let editor = std::env::var("VISUAL")
                .or_else(|_| std::env::var("EDITOR"))
                .unwrap_or_else(|_| "vi".into());
            let mut parts = editor.split_whitespace();
            let prog = parts.next().unwrap_or("vi").to_string();
            let args: Vec<&str> = parts.collect();
            let st = Command::new(&prog).args(args).arg(&path).status();
            *term = ratatui::init();
            term.clear()?;
            if let Err(e) = st {
                app.status = format!("Couldn't launch editor '{prog}': {e}");
            } else {
                app.status = "Back from editor — press r to run".into();
            }
        }
        if app.quit {
            return Ok(());
        }
    }
}

fn main() -> io::Result<()> {
    let mut term = ratatui::init();
    let res = run(&mut term);
    ratatui::restore();
    res
}
