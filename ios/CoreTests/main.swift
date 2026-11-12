import Foundation

// Off-device check of the game rules: a bot plays, then a careless player loses.
var failures = 0
func check(_ ok: Bool, _ what: String) { print((ok ? "PASS  " : "FAIL  ") + what); if !ok { failures += 1 } }

let dt = 1.0 / 120

// 1. A bot that lets go when the firefly points at the next lantern keeps climbing.
do {
    let g = GameCore(); g.H = 866; g.start()
    var taps = 0, hops = 0, deaths = 0
    for _ in 0..<(120 * 45) {
        if g.phase != .play { break }
        if g.mode == .orbit, let next = g.lanterns.first(where: { $0.idx == g.cur.idx + 1 }) {
            let dx = g.dir * -sin(g.angle), dy = g.dir * cos(g.angle)
            let rx = next.x - g.px, ry = next.y - g.py
            if rx * dx + ry * dy > 0 && abs(rx * dy - ry * dx) < next.r * 0.5 { g.tap(); taps += 1 }
        }
        g.update(dt)
        for e in g.drainEvents() { if case .hop = e { hops += 1 }; if case .died = e { deaths += 1 } }
    }
    print("bot: taps \(taps), hops \(hops), score \(g.score), reached lantern \(g.maxIdx)")
    check(deaths == 0 && g.phase == .play, "bot survives 45 seconds")
    check(hops >= 25, "bot lands at least 25 lanterns")
    check(g.score >= hops, "score is at least one point per lantern")
    check(g.lanterns.count <= 40, "old lanterns are cleaned up")
}

// 2. Tapping blindly ends the run, and nothing moves the score after death.
do {
    var ended = 0
    for _ in 0..<20 {
        let g = GameCore(); g.H = 700; g.start()
        var i = 0
        while g.phase == .play && i < 120 * 120 { if i % 37 == 0 { g.tap() }; g.update(dt); i += 1 }
        if g.phase == .dead { ended += 1; let s = g.score; g.tap(); g.update(dt); if g.score != s { failures += 1 } }
    }
    check(ended == 20, "blind tapping always ends the run (\(ended)/20)")
}

// 3. Sitting on a lantern after the first hop burns it out.
do {
    let g = GameCore(); g.H = 700; g.start()
    var burned = false
    for _ in 0..<(120 * 60) {
        if g.phase != .play { break }
        if g.maxIdx == 0, g.mode == .orbit, let next = g.lanterns.first(where: { $0.idx == 1 }) {
            let dx = g.dir * -sin(g.angle), dy = g.dir * cos(g.angle)
            let rx = next.x - g.px, ry = next.y - g.py
            if rx * dx + ry * dy > 0 && abs(rx * dy - ry * dx) < next.r * 0.5 { g.tap() }
        }
        g.update(dt)
        for e in g.drainEvents() { if case .died(let why) = e, why == .burned { burned = true } }
    }
    check(burned, "waiting too long burns the lantern out")
}

// 4. The start lantern never burns before the first hop.
do {
    let g = GameCore(); g.start()
    for _ in 0..<(120 * 30) { g.update(dt) }
    check(g.phase == .play && g.cur.fuse == 1, "no timer before the first hop")
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
