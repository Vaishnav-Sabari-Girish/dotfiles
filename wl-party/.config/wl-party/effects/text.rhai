// Types out text in dots, letter by letter, then fades it (use "|" for a new line)

const TEXT = "HAPPY NEW|YEAR|2027";
const TYPE_DELAY = 0.15;  // seconds between letters
const HOLD = 4.0;         // seconds each dot stays once it appears
const COLORS = ["#ff4d6d", "#ffb347", "#ffe066", "#5ce1e6", "#7b61ff", "#3ddc84", "#ff7ac8"];

// Supported characters: A-Z 0-9 ! ? . , - : ' and * (a heart). Anything else is skipped.
// Each glyph is 5 wide and 7 tall; rows are separated by "/".
const CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,-:'*";
const GLYPHS = [
    ".###./#...#/#...#/#####/#...#/#...#/#...#",   // A
    "####./#...#/#...#/####./#...#/#...#/####.",   // B
    ".###./#...#/#..../#..../#..../#...#/.###.",   // C
    "####./#...#/#...#/#...#/#...#/#...#/####.",   // D
    "#####/#..../#..../####./#..../#..../#####",   // E
    "#####/#..../#..../####./#..../#..../#....",   // F
    ".###./#...#/#..../#.###/#...#/#...#/.###.",   // G
    "#...#/#...#/#...#/#####/#...#/#...#/#...#",   // H
    ".###./..#../..#../..#../..#../..#../.###.",   // I
    "..###/...#./...#./...#./...#./#..#./.##..",   // J
    "#...#/#..#./#.#../##.../#.#../#..#./#...#",   // K
    "#..../#..../#..../#..../#..../#..../#####",   // L
    "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",   // M
    "#...#/##..#/#.#.#/#..##/#...#/#...#/#...#",   // N
    ".###./#...#/#...#/#...#/#...#/#...#/.###.",   // O
    "####./#...#/#...#/####./#..../#..../#....",   // P
    ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",   // Q
    "####./#...#/#...#/####./#.#../#..#./#...#",   // R
    ".####/#..../#..../.###./....#/....#/####.",   // S
    "#####/..#../..#../..#../..#../..#../..#..",   // T
    "#...#/#...#/#...#/#...#/#...#/#...#/.###.",   // U
    "#...#/#...#/#...#/#...#/#...#/.#.#./..#..",   // V
    "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",   // W
    "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",   // X
    "#...#/#...#/.#.#./..#../..#../..#../..#..",   // Y
    "#####/....#/...#./..#../.#.../#..../#####",   // Z
    ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",   // 0
    "..#../.##../..#../..#../..#../..#../.###.",   // 1
    ".###./#...#/....#/...#./..#../.#.../#####",   // 2
    "####./....#/....#/.###./....#/....#/####.",   // 3
    "...#./..##./.#.#./#..#./#####/...#./...#.",   // 4
    "#####/#..../####./....#/....#/#...#/.###.",   // 5
    ".###./#..../#..../####./#...#/#...#/.###.",   // 6
    "#####/....#/...#./..#../.#.../.#.../.#...",   // 7
    ".###./#...#/#...#/.###./#...#/#...#/.###.",   // 8
    ".###./#...#/#...#/.####/....#/....#/.###.",   // 9
    "..#../..#../..#../..#../..#../...../..#..",   // !
    ".###./#...#/....#/...#./..#../...../..#..",   // ?
    "...../...../...../...../...../.##../.##..",   // .
    "...../...../...../...../.##../..#../.#...",   // ,
    "...../...../...../#####/...../...../.....",   // -
    "...../.##../.##../...../.##../.##../.....",   // :
    "..#../..#../.#.../...../...../...../.....",   // '
    ".#.#./#####/#####/#####/.###./..#../.....",   // * (heart)
];

// The 7 rows of a character's glyph, or an empty list if there isn't one.
// (Constants aren't visible inside helper functions, so they're passed in.)
fn glyph(chars, glyphs, ch) {
    let i = chars.index_of(ch);
    if i < 0 {
        return [];
    }
    glyphs[i].split("/")
}

fn start(ctx) {
    // No real gravity: dots are placed exactly where they belong and stay put.
    // (A tiny value keeps the parked dots below from being dropped as "gone".)
    ctx.gravity = 0.001;
    ctx.drag = 1.0;

    let lines = TEXT.to_upper().split("|");

    // Size the grid so the whole text fits the screen.
    let widest = 1;
    for line in lines {
        let n = line.len() * 6 - 1;
        if n > widest {
            widest = n;
        }
    }
    let grid_rows = lines.len() * 8 - 1;
    let cell = ctx.width * 0.9 / widest.to_float();
    let by_height = ctx.height * 0.8 / grid_rows.to_float();
    if by_height < cell {
        cell = by_height;
    }
    if cell > 48.0 {
        cell = 48.0;
    }
    let top = (ctx.height - grid_rows.to_float() * cell) / 2.0;

    let emitted = 0;
    let typed = 0;
    for li in 0..lines.len() {
        let line = lines[li];
        let left = (ctx.width - (line.len() * 6 - 1).to_float() * cell) / 2.0;
        for ci in 0..line.len() {
            let rows = glyph(CHARS, GLYPHS, line.sub_string(ci, 1));
            if rows.len() < 7 {
                continue;
            }
            let color = COLORS[(li + ci) % COLORS.len()];
            let when = typed.to_float() * TYPE_DELAY + 0.05;
            typed += 1;
            for r in 0..7 {
                let row = rows[r];
                for c in 0..5 {
                    if row.sub_string(c, 1) != "#" || emitted >= 5000 {
                        continue;
                    }
                    emitted += 1;

                    let tx = left + ((ci * 6 + c).to_float() + 0.5) * cell;
                    let ty = top + ((li * 8 + r).to_float() + 0.5) * cell;
                    let size = cell * 0.85;

                    // Parked above the screen until its turn. Where the dot
                    // goes is packed into the tag: "x;y;size;color".
                    ctx.emit(#{
                        x: tx,
                        y: -ctx.height * 2.0,
                        fuse: when,
                        size: 1,
                        tag: tx.to_string() + ";" + ty.to_string() + ";" + size.to_string() + ";" + color,
                    });
                }
            }
        }
    }
}

// A parked dot's turn: put the real dot at its exact spot.
fn expire(ctx, p) {
    let a = p.tag.split(";");
    if a.len() < 4 {
        return;
    }
    ctx.emit(#{
        x: parse_float(a[0]),
        y: parse_float(a[1]),
        size: parse_float(a[2]),
        color: a[3],
        shape: "circle",
        shadow: "#1d2b3a",
        spin: false,
        fuse: HOLD,
        tag: "dot",
    });
}
