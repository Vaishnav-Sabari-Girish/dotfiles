#!/usr/bin/env rust-script
//! Terminal audio/video trimmer with a mouse-driven timeline.
//!
//! Usage:  rust-script trim.rs <input-file>
//! Needs:  ffmpeg, ffprobe (and ffplay for the preview key) on PATH.
//!
//! ```cargo
//! [dependencies]
//! ratatui = "*"
//! anyhow = "*"
//! ```

use anyhow::{bail, Context, Result};
use ratatui::{
    crossterm::{
        event::{
            self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind,
            KeyModifiers, MouseButton, MouseEventKind,
        },
        execute,
    },
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Paragraph},
    DefaultTerminal, Frame,
};
use std::{
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    time::{Duration, Instant},
};

const MIN_GAP: f64 = 0.05;
const VALUE_W: usize = 12;
/// Left-aligned partial blocks, 1/8 .. 8/8 of a cell. Used for sub-cell playhead movement.
const EIGHTHS: [&str; 8] = ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"];

#[derive(Clone, Copy, PartialEq)]
enum Handle {
    Start,
    End,
}

struct App {
    file: PathBuf,
    is_video: bool,
    dur: f64,
    start: f64,
    end: f64,
    active: Handle,
    dragging: bool,
    editing: Option<(Handle, String)>,
    accurate: bool,
    status: String,
    timeline: Rect,
    start_box: Rect,
    end_box: Rect,
    preview: Option<Child>,
    play_clock: Option<Instant>,
    play_from: f64,
    play_len: f64,
}

fn hit(r: Rect, x: u16, y: u16) -> bool {
    x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height
}

fn fmt(t: f64) -> String {
    let ms = (t.max(0.0) * 1000.0).round() as u64;
    format!(
        "{:02}:{:02}:{:02}.{:03}",
        ms / 3_600_000,
        ms / 60_000 % 60,
        ms / 1000 % 60,
        ms % 1000
    )
}

fn short(t: f64) -> String {
    let s = t.max(0.0).round() as u64;
    if s >= 3600 {
        format!("{}:{:02}:{:02}", s / 3600, s / 60 % 60, s % 60)
    } else {
        format!("{}:{:02}", s / 60, s % 60)
    }
}

/// Accepts SS, SS.mmm, MM:SS, HH:MM:SS(.mmm)
fn parse_time(s: &str) -> Option<f64> {
    let parts: Vec<&str> = s.trim().split(':').collect();
    if parts.is_empty() || parts.len() > 3 {
        return None;
    }
    let mut total = 0.0;
    for p in parts {
        let v: f64 = p.parse().ok()?;
        if v < 0.0 {
            return None;
        }
        total = total * 60.0 + v;
    }
    Some(total)
}

impl App {
    fn get(&self, h: Handle) -> f64 {
        match h {
            Handle::Start => self.start,
            Handle::End => self.end,
        }
    }

    fn set(&mut self, h: Handle, t: f64) {
        match h {
            Handle::Start => self.start = t.clamp(0.0, (self.end - MIN_GAP).max(0.0)),
            Handle::End => self.end = t.clamp((self.start + MIN_GAP).min(self.dur), self.dur),
        }
    }

    fn adjust(&mut self, delta: f64) {
        let h = self.active;
        let cur = self.get(h);
        self.set(h, cur + delta);
    }

    fn time_at(&self, col: u16) -> f64 {
        let w = self.timeline.width.saturating_sub(1).max(1) as f64;
        let rel = col.saturating_sub(self.timeline.x) as f64;
        rel.min(w) / w * self.dur
    }

    /// Fractional column for a time (sub-cell precision).
    fn colf(&self, t: f64, width: usize) -> f64 {
        let w = width.saturating_sub(1).max(1) as f64;
        (t / self.dur * w).clamp(0.0, w)
    }

    /// Current playback position (seconds) while a preview is running.
    fn playhead(&mut self) -> Option<f64> {
        let child = self.preview.as_mut()?;
        if let Ok(Some(_)) = child.try_wait() {
            self.preview = None;
            self.play_clock = None;
            self.status = "Preview finished".into();
            return None;
        }
        let elapsed = self.play_clock?.elapsed().as_secs_f64();
        Some(self.play_from + elapsed.min(self.play_len))
    }

    fn stop_preview(&mut self) {
        if let Some(mut c) = self.preview.take() {
            let _ = c.kill();
            let _ = c.wait();
        }
        self.play_clock = None;
    }

    fn start_preview(&mut self) {
        self.stop_preview();
        let mut cmd = Command::new("ffplay");
        cmd.args(["-hide_banner", "-loglevel", "quiet", "-autoexit"]);
        if !self.is_video {
            cmd.arg("-nodisp");
        }
        let ss = format!("{:.3}", self.start);
        let t = format!("{:.3}", self.end - self.start);
        cmd.args(["-ss", &ss, "-t", &t]).arg(&self.file);
        cmd.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());
        match cmd.spawn() {
            Ok(c) => {
                self.preview = Some(c);
                self.play_clock = Some(Instant::now());
                self.play_from = self.start;
                self.play_len = self.end - self.start;
                self.status = "▶ Playing".into();
            }
            Err(_) => self.status = "ffplay not found (comes with ffmpeg)".into(),
        }
    }

    fn draw(&mut self, f: &mut Frame) {
        let playhead = self.playhead();
        if let Some(p) = playhead {
            self.status = format!("▶ {} / {}", fmt(p), fmt(self.end));
        }

        let full = f.area();
        // Fixed-size layout, centered both ways in the terminal.
        const CONTENT_H: u16 = 15; // title 1 + timeline 5 + selection 3 + help 5 + status 1
        const MAX_W: u16 = 100;
        let width = full.width.saturating_sub(2).min(MAX_W);
        let height = full.height.min(CONTENT_H);
        let area = Rect {
            x: full.x + (full.width.saturating_sub(width)) / 2,
            y: full.y + (full.height.saturating_sub(height)) / 2,
            width,
            height,
        };
        let rows = Layout::vertical([
            Constraint::Length(1), // title (plain)
            Constraint::Length(5), // timeline box (2 bar rows + ruler)
            Constraint::Length(3), // selection box (start / end / length)
            Constraint::Length(5), // help box
            Constraint::Length(1), // status (plain)
        ])
        .split(area);

        // Title
        let kind = if self.is_video { "video" } else { "audio" };
        let mode = if self.accurate { "accurate" } else { "fast copy" };
        let title = Line::from(vec![
            Span::styled(
                self.file.file_name().and_then(|s| s.to_str()).unwrap_or("?").to_string(),
                Style::new().add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {kind} · {} · {mode}", short(self.dur)),
                Style::new().fg(Color::DarkGray),
            ),
        ]);
        f.render_widget(Paragraph::new(title), rows[0]);

        // Timeline
        let tl_block = Block::bordered().title(" Timeline ");
        let inner = tl_block.inner(rows[1]);
        f.render_widget(tl_block, rows[1]);
        self.timeline = inner;
        let w = inner.width as usize;
        let sc = self.colf(self.start, w).round() as usize;
        let ec = self.colf(self.end, w).round() as usize;
        let pf = playhead.map(|p| self.colf(p, w));
        let (pcell, pk) = match pf {
            Some(v) => {
                let c = v.floor();
                (Some(c as usize), ((v - c) * 8.0).round() as usize)
            }
            None => (None, 0),
        };

        let mut spans = Vec::with_capacity(w);
        for x in 0..w {
            let inside = x > sc && x < ec;
            let span = if x == sc || x == ec {
                let is_start = x == sc && x != ec;
                let (color, h) = if is_start {
                    (Color::Cyan, Handle::Start)
                } else {
                    (Color::Magenta, Handle::End)
                };
                let style = if self.active == h {
                    Style::new().fg(Color::Black).bg(color)
                } else {
                    Style::new().fg(color).add_modifier(Modifier::BOLD)
                };
                Span::styled("┃", style)
            } else if inside {
                match pcell {
                    Some(c) if x < c => Span::styled("█", Style::new().fg(Color::Yellow)),
                    Some(c) if x == c && pk >= 8 => Span::styled("█", Style::new().fg(Color::Yellow)),
                    Some(c) if x == c && pk > 0 => Span::styled(
                        EIGHTHS[pk - 1],
                        Style::new().fg(Color::Yellow).bg(Color::Green),
                    ),
                    _ => Span::styled("█", Style::new().fg(Color::Green)),
                }
            } else {
                Span::styled("░", Style::new().fg(Color::DarkGray))
            };
            spans.push(span);
        }
        let bar = Line::from(spans);
        let l = short(0.0);
        let r = short(self.dur);
        let pad = w.saturating_sub(l.len() + r.len());
        let ruler = Line::from(Span::styled(
            format!("{l}{}{r}", " ".repeat(pad)),
            Style::new().fg(Color::DarkGray),
        ));
        f.render_widget(Paragraph::new(vec![bar.clone(), bar, ruler]), inner);

        // Start / End / Length on one line
        let sel_block = Block::bordered().title(" Selection ");
        let frow = sel_block.inner(rows[2]);
        f.render_widget(sel_block, rows[2]);
        let mut x = frow.x + 1;
        let mut spans: Vec<Span> = vec![Span::raw(" ")];
        for (h, label, color) in [
            (Handle::Start, "Start ", Color::Cyan),
            (Handle::End, "End   ", Color::Magenta),
        ] {
            let editing_this = matches!(&self.editing, Some((eh, _)) if *eh == h);
            let val = if editing_this {
                let mut s = format!("{}_", self.editing.as_ref().unwrap().1);
                if s.len() > VALUE_W {
                    s = s[s.len() - VALUE_W..].to_string();
                }
                format!("{s:<VALUE_W$}")
            } else {
                fmt(self.get(h))
            };
            let vstyle = if editing_this {
                Style::new().fg(Color::Black).bg(Color::Yellow)
            } else if self.active == h {
                Style::new().fg(Color::Black).bg(color)
            } else {
                Style::new().fg(color)
            };
            spans.push(Span::styled(label, Style::new().fg(Color::DarkGray)));
            spans.push(Span::styled(val, vstyle));
            spans.push(Span::raw("    "));
            let rect = Rect {
                x,
                y: frow.y,
                width: (label.len() + VALUE_W) as u16,
                height: 1,
            };
            if h == Handle::Start {
                self.start_box = rect;
            } else {
                self.end_box = rect;
            }
            x += rect.width + 4;
        }
        spans.push(Span::styled("Length ", Style::new().fg(Color::DarkGray)));
        spans.push(Span::raw(fmt(self.end - self.start)));
        f.render_widget(Paragraph::new(Line::from(spans)), frow);

        // Help
        let help = vec![
            Line::from("click/drag timeline · click a time to type it · scroll ±1s"),
            Line::from("Tab handle · ←/→ ±1s (Shift ±10s) · , . ±0.1s · s/e type · m fast/accurate"),
            Line::from("p / Space play-stop · Enter export · q quit"),
        ];
        f.render_widget(
            Paragraph::new(help)
                .style(Style::new().fg(Color::DarkGray))
                .block(Block::bordered().title(" Help ")),
            rows[3],
        );

        f.render_widget(
            Paragraph::new(self.status.as_str()).style(Style::new().fg(Color::Yellow)),
            rows[4],
        );
    }
}

/// Handles one event. Returns Some(true) to export, Some(false) to quit.
fn handle(app: &mut App, ev: Event) -> Option<bool> {
    match ev {
        Event::Key(key) if key.kind == KeyEventKind::Press => {
            if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
                return Some(false);
            }
            if let Some((h, buf)) = app.editing.as_mut() {
                let h = *h;
                match key.code {
                    KeyCode::Char(c) if c.is_ascii_digit() || c == ':' || c == '.' => buf.push(c),
                    KeyCode::Backspace => {
                        buf.pop();
                    }
                    KeyCode::Esc => {
                        app.editing = None;
                        app.status.clear();
                    }
                    KeyCode::Enter => {
                        let text = buf.clone();
                        app.editing = None;
                        match parse_time(&text) {
                            Some(t) if t <= app.dur => {
                                app.set(h, t);
                                app.active = h;
                                app.status.clear();
                            }
                            Some(_) => app.status = format!("Time is past the end ({})", fmt(app.dur)),
                            None => app.status = "Couldn't parse that time".into(),
                        }
                    }
                    _ => {}
                }
                return None;
            }
            let shift = key.modifiers.contains(KeyModifiers::SHIFT);
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => return Some(false),
                KeyCode::Enter => return Some(true),
                KeyCode::Tab => {
                    app.active = if app.active == Handle::Start { Handle::End } else { Handle::Start };
                }
                KeyCode::Left => app.adjust(if shift { -10.0 } else { -1.0 }),
                KeyCode::Right => app.adjust(if shift { 10.0 } else { 1.0 }),
                KeyCode::Char(',') => app.adjust(-0.1),
                KeyCode::Char('.') => app.adjust(0.1),
                KeyCode::Char('s') => app.editing = Some((Handle::Start, String::new())),
                KeyCode::Char('e') => app.editing = Some((Handle::End, String::new())),
                KeyCode::Char('m') => app.accurate = !app.accurate,
                KeyCode::Char('p') | KeyCode::Char(' ') => {
                    if app.preview.is_some() {
                        app.stop_preview();
                        app.status = "Preview stopped".into();
                    } else {
                        app.start_preview();
                    }
                }
                _ => {}
            }
            None
        }
        Event::Mouse(m) => {
            match m.kind {
                MouseEventKind::Down(MouseButton::Left) => {
                    if hit(app.start_box, m.column, m.row) {
                        app.editing = Some((Handle::Start, String::new()));
                    } else if hit(app.end_box, m.column, m.row) {
                        app.editing = Some((Handle::End, String::new()));
                    } else if hit(app.timeline, m.column, m.row) {
                        app.editing = None;
                        let t = app.time_at(m.column);
                        let h = if t < app.start {
                            Handle::Start
                        } else if t > app.end {
                            Handle::End
                        } else if (t - app.start).abs() < (t - app.end).abs() {
                            Handle::Start
                        } else {
                            Handle::End
                        };
                        app.active = h;
                        app.set(h, t);
                        app.dragging = true;
                    }
                }
                MouseEventKind::Drag(MouseButton::Left) if app.dragging => {
                    let t = app.time_at(m.column);
                    let h = app.active;
                    app.set(h, t);
                }
                MouseEventKind::Up(MouseButton::Left) => app.dragging = false,
                MouseEventKind::ScrollUp => app.adjust(1.0),
                MouseEventKind::ScrollDown => app.adjust(-1.0),
                _ => {}
            }
            None
        }
        _ => None,
    }
}

/// Returns Ok(true) to export, Ok(false) to quit.
fn run(terminal: &mut DefaultTerminal, app: &mut App) -> Result<bool> {
    let mut dirty = true;
    loop {
        // Only redraw when something changed or the playhead is moving.
        if dirty || app.preview.is_some() {
            terminal.draw(|f| app.draw(f))?;
            dirty = false;
        }
        let wait = if app.preview.is_some() {
            Duration::from_millis(16)
        } else {
            Duration::from_millis(250)
        };
        if event::poll(wait)? {
            // Drain everything queued (e.g. a burst of drag events) before the next draw,
            // so dragging never lags behind the mouse.
            loop {
                let ev = event::read()?;
                if let Some(result) = handle(app, ev) {
                    return Ok(result);
                }
                dirty = true;
                if !event::poll(Duration::ZERO)? {
                    break;
                }
            }
        }
    }
}

fn probe_duration(p: &Path) -> Result<f64> {
    let out = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(p)
        .output()
        .context("ffprobe not found — install ffmpeg first")?;
    String::from_utf8_lossy(&out.stdout)
        .trim()
        .parse::<f64>()
        .context("could not read media duration (is this a valid audio/video file?)")
}

fn is_audio_ext(p: &Path) -> bool {
    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
    matches!(
        ext.as_str(),
        "mp3" | "wav" | "flac" | "aac" | "m4a" | "ogg" | "opus" | "wma" | "aiff" | "aif" | "amr"
    )
}

fn out_path(input: &Path) -> PathBuf {
    let stem = input.file_stem().and_then(|s| s.to_str()).unwrap_or("out");
    let ext = input.extension().and_then(|s| s.to_str()).unwrap_or("mp4");
    let dir = input.parent().filter(|p| !p.as_os_str().is_empty()).unwrap_or(Path::new("."));
    let mut i = 0;
    loop {
        let name = if i == 0 {
            format!("{stem}_trim.{ext}")
        } else {
            format!("{stem}_trim_{i}.{ext}")
        };
        let p = dir.join(name);
        if !p.exists() {
            return p;
        }
        i += 1;
    }
}

fn export(app: &App) -> Result<()> {
    let out = out_path(&app.file);
    let ss = format!("{:.3}", app.start);
    let t = format!("{:.3}", app.end - app.start);
    println!(
        "Trimming {} → {}  ({} – {})\n",
        app.file.display(),
        out.display(),
        fmt(app.start),
        fmt(app.end)
    );
    let mut cmd = Command::new("ffmpeg");
    cmd.args(["-hide_banner", "-n", "-ss", &ss, "-i"]).arg(&app.file);
    cmd.args(["-t", &t]);
    if !app.accurate {
        cmd.args(["-c", "copy", "-avoid_negative_ts", "make_zero"]);
    }
    cmd.arg(&out);
    let status = cmd.status().context("failed to run ffmpeg")?;
    if !status.success() {
        bail!("ffmpeg exited with {status}");
    }
    println!("\nDone: {}", out.display());
    Ok(())
}

fn main() -> Result<()> {
    let Some(arg) = std::env::args().nth(1) else {
        eprintln!("Usage: rust-script trim.rs <audio-or-video-file>");
        std::process::exit(2);
    };
    let file = PathBuf::from(arg);
    if !file.is_file() {
        bail!("file not found: {}", file.display());
    }
    let dur = probe_duration(&file)?;
    if dur <= MIN_GAP {
        bail!("media is too short to trim");
    }

    let mut app = App {
        is_video: !is_audio_ext(&file),
        file,
        dur,
        start: 0.0,
        end: dur,
        active: Handle::Start,
        dragging: false,
        editing: None,
        accurate: true,
        status: String::new(),
        timeline: Rect::default(),
        start_box: Rect::default(),
        end_box: Rect::default(),
        preview: None,
        play_clock: None,
        play_from: 0.0,
        play_len: 0.0,
    };

    let mut terminal = ratatui::init();
    let _ = execute!(std::io::stdout(), EnableMouseCapture);
    let res = run(&mut terminal, &mut app);
    let _ = execute!(std::io::stdout(), DisableMouseCapture);
    ratatui::restore();
    app.stop_preview();

    if res? {
        export(&app)
    } else {
        println!("Cancelled.");
        Ok(())
    }
}
