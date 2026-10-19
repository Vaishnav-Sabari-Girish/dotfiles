// Rockets shoot up and explode as bursts, rings or hearts

const ROCKET = "M0 -10 C4 -6 4 2 3 6 L5 10 L-5 10 L-3 6 C-4 2 -4 -6 0 -10 Z";
const COLORS = ["#ff4d6d", "#ffe066", "#5ce1e6", "#7b61ff", "#3ddc84", "#ff7ac8"];
const KINDS = ["burst", "ring", "heart"];

fn pick(list) {
    list[(rand() * list.len()).to_int()]
}

fn start(ctx) {
    ctx.gravity = ctx.height * 0.5;
    let rockets = 6;
    for i in 0..rockets {
        // Parked above the screen, where nothing is drawn or removed, until its fuse launches the rocket.
        ctx.emit(#{
            x: ctx.width * (0.25 + 0.5 * rand()),
            y: -ctx.height * 2.0,
            fuse: i * 0.35 + rand() * 0.25,
            size: 1,
            tag: "launch",
        });
    }
}

// Launch speed that climbs `rise` pixels in `fuse` seconds, with gravity and drag.
fn launch_speed(ctx, rise, fuse) {
    let k = ctx.drag;
    let g = ctx.gravity;
    g / k - (rise + g * fuse / k) * k / (1.0 - (-k * fuse).exp())
}

fn expire(ctx, p) {
    if p.tag == "launch" {
        let fuse = 1.0 + rand() * 0.4;
        let rise = ctx.height * (0.6 + rand() * 0.25);
        ctx.emit(#{
            x: p.x,
            y: ctx.height,
            vx: (rand() - 0.5) * 40.0,
            vy: launch_speed(ctx, rise, fuse),
            fuse: fuse,
            shape: ROCKET,
            size: 28,
            color: "#dddddd",
            spin: false,
            tag: pick(KINDS),
        });
        return;
    }
    let color = pick(COLORS);
    let scale = 0.6 + rand() * 0.8;
    let sparks = (ctx.count / 6 * scale).to_int();
    switch p.tag {
        "burst" => burst(ctx, p, sparks, scale, color),
        "ring" => ring(ctx, p, sparks, scale, color),
        "heart" => heart(ctx, p, sparks, scale, color),
    }
}

fn burst(ctx, p, sparks, scale, color) {
    let speed = ctx.height * 0.35 * scale;
    for i in 0..sparks {
        let angle = 2.0 * PI() * rand();
        let v = speed * (0.3 + rand() * 0.7);
        spark(ctx, p, angle.cos() * v, angle.sin() * v, color);
    }
}

fn ring(ctx, p, sparks, scale, color) {
    let speed = ctx.height * 0.3 * scale;
    for i in 0..sparks {
        let angle = 2.0 * PI() * i / sparks;
        spark(ctx, p, angle.cos() * speed, angle.sin() * speed, color);
    }
}

// The classic parametric heart: x = 16 sin³t, y = 13 cos t - 5 cos 2t - 2 cos 3t - cos 4t.
fn heart(ctx, p, sparks, scale, color) {
    let speed = ctx.height * 0.02 * scale;
    for i in 0..sparks {
        let t = 2.0 * PI() * i / sparks;
        let x = 16.0 * t.sin() ** 3;
        let y = 13.0 * t.cos() - 5.0 * (2.0 * t).cos() - 2.0 * (3.0 * t).cos() - (4.0 * t).cos();
        spark(ctx, p, x * speed, -y * speed, color);
    }
}

fn spark(ctx, p, vx, vy, color) {
    ctx.emit(#{ x: p.x, y: p.y, vx: vx, vy: vy, fuse: 1.4, shape: "circle", size: 6, color: color });
}
