// Balloons float up from the bottom

const BALLOON = "M0 -12 C7 -12 10 -6 10 -1 C10 6 4 11 1 12 L2 14 L-2 14 L-1 12 C-4 11 -10 6 -10 -1 C-10 -6 -7 -12 0 -12 Z";
const COLORS = ["#ff4d6dd0", "#ffb347d0", "#ffe066d0", "#5ce1e6d0", "#7b61ffd0", "#3ddc84d0", "#ff7ac8d0"];

fn start(ctx) {
    ctx.gravity = -ctx.height * 0.05;
    ctx.drag = 0.3;
    for i in 0..ctx.count / 10 {
        ctx.emit(#{
            x: rand() * ctx.width,
            y: ctx.height + 60.0 + rand() * ctx.height * 0.8,
            vx: (rand() - 0.5) * 30.0,
            vy: -ctx.height * (0.15 + rand() * 0.1),
            shape: BALLOON,
            size: 50.0 + rand() * 40.0,
            color: COLORS[(rand() * COLORS.len()).to_int()],
            spin: false,
            wobble: 12.0 + rand() * 8.0,
            gloss: true,
        });
    }
}
