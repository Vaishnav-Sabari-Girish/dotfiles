// Snowflakes drift down from the top

// Six arms with side branches, drawn as overlapping bars.
const FLAKE = "M0 6 L0 -6 L100 -6 L100 6 Z M58 3 L52 -3 L74 -26 L81 -19 Z M52 3 L58 -3 L81 19 L74 26 Z M-5 3 L5 -3 L55 84 L45 90 Z M26 52 L29 43 L60 52 L57 60 Z M23 46 L32 49 L24 80 L15 77 Z M-5 -3 L5 3 L-45 90 L-55 84 Z M-32 49 L-23 46 L-15 77 L-24 80 Z M-29 43 L-26 52 L-57 60 L-60 52 Z M-0 -6 L0 6 L-100 6 L-100 -6 Z M-58 -3 L-52 3 L-74 26 L-81 19 Z M-52 -3 L-58 3 L-81 -19 L-74 -26 Z M5 -3 L-5 3 L-55 -84 L-45 -90 Z M-26 -52 L-29 -43 L-60 -52 L-57 -60 Z M-23 -46 L-32 -49 L-24 -80 L-15 -77 Z M5 3 L-5 -3 L45 -90 L55 -84 Z M32 -49 L23 -46 L15 -77 L24 -80 Z M29 -43 L26 -52 L57 -60 L60 -52 Z";

fn start(ctx) {
    ctx.gravity = 130.0;
    ctx.drag = 0.6;
    for i in 0..ctx.count {
        ctx.emit(#{
            x: rand() * ctx.width,
            // All flakes fall at the same speed, so their spread on screen is their spread at the start.
            y: -20.0 - rand() * ctx.height,
            vx: (rand() - 0.5) * 40.0,
            vy: 100.0 + rand() * 60.0,
            shape: FLAKE,
            size: 8.0 + rand() * 14.0,
            color: "#ffffff",
            shadow: "#2b4a6b",
            spin: false,
            wobble: 10.0 + rand() * 25.0,
        });
    }
}
