#!/usr/bin/env rust-script
//! Toggle mute on every audio input-capture source in the current OBS
//! scene collection, so it works with any profile.
//!
//! ```cargo
//! [dependencies]
//! obws = "0.14"
//! tokio = { version = "1", features = ["rt", "macros"] }
//! ```

use obws::{requests::inputs::InputId, Client};

// Input kinds that count as "mic". Run `obs-cmd` or the websocket
// GetInputKindList request to see what your install uses
// (PulseAudio: pulse_input_capture).
const KINDS: &[&str] = &[
    "pulse_input_capture",
    "pipewire-audio-capture-input",
];

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // File holds obsws://host:port/password (same format obs-cmd uses)
    let path = format!(
        "{}/dotfiles/niri/.config/niri/obs-websocket",
        std::env::var("HOME")?
    );
    let raw = std::fs::read_to_string(path)?;
    let rest = raw.trim().trim_start_matches("obsws://");
    let (hostport, password) = rest.split_once('/').unwrap_or((rest, ""));
    let (host, port) = hostport.split_once(':').unwrap_or((hostport, "4455"));

    let client = Client::connect(
        host,
        port.parse::<u16>()?,
        if password.is_empty() { None } else { Some(password) },
    )
    .await?;

    let mut names = Vec::new();
    for kind in KINDS {
        for input in client.inputs().list(Some(kind)).await? {
            names.push(input.id.name);
        }
    }

    if names.is_empty() {
        eprintln!("No audio input capture sources found");
        std::process::exit(1);
    }

    // Flip based on the first source's state so all end up in sync
    let currently_muted = client.inputs().muted(InputId::Name(&names[0])).await?;
    for name in &names {
        client
            .inputs()
            .set_muted(InputId::Name(name), !currently_muted)
            .await?;
    }
    Ok(())
}
