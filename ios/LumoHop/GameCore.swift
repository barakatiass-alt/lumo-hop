import Foundation

// Pure game simulation for Lumo Hop. No UI imports: this file also compiles and runs off-device for tests.
// Coordinates are logical units: the playfield is 400 wide, y grows downward, the camera climbs toward negative y.

public struct RGB {
    public var r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
}

public func pmod(_ v: Double, _ m: Double) -> Double {
    let r = v.truncatingRemainder(dividingBy: m)
    return r < 0 ? r + m : r
}

public func hslToRgb(_ hDeg: Double, _ sPct: Double, _ lPct: Double) -> RGB {
    let h = pmod(hDeg, 360) / 360, s = sPct / 100, l = lPct / 100
    func f(_ n: Double) -> Double {
        let k = (n + h * 12).truncatingRemainder(dividingBy: 12)
        let a = s * min(l, 1 - l)
        return (255 * (l - a * max(-1, min(k - 3, min(9 - k, 1))))).rounded()
    }
    return RGB(f(0), f(8), f(4))
}

public final class Lantern {
    public let idx: Int
    public var bx: Double
    public var x: Double
    public let y: Double
    public let r: Double
    public var amp = 0.0
    public var sp = 0.0
    public let ph: Double
    public let hue: Double
    public var fuse = 1.0
    public var lit = true
    public var visited: Bool
    public let sway: Double
    public var pop = 0.0
    init(idx: Int, x: Double, y: Double, r: Double, hue: Double) {
        self.idx = idx; self.bx = x; self.x = x; self.y = y; self.r = r; self.hue = hue
        self.ph = Double.random(in: 0...(2 * Double.pi)); self.sway = Double.random(in: 0...(2 * Double.pi))
        self.visited = idx == 0
    }
}

public struct Gem { public var x: Double, y: Double, got: Bool, ph: Double }
public struct Particle { public var x: Double, y: Double, vx: Double, vy: Double, life: Double, maxLife: Double, color: RGB, size: Double }
public enum TextTone { case ink, jade, ember }
public struct FloatText { public var x: Double, y: Double, text: String, tone: TextTone, size: Double, life: Double }
public struct TrailPoint { public var x: Double, y: Double }

public enum Mode { case orbit, fly, dead }
public enum Phase { case menu, play, dead }
public enum DeathReason { case burned, lost }
public enum GameEvent { case hop(note: Int), rehop, leap, wall, gem, died(DeathReason) }

public struct Theme { public let top: RGB, mid: RGB, bot: RGB, hue: Double }

public final class GameCore {
    public static let W = 400.0
    public static let maxFlight = 2.4
    public static let themes: [Theme] = [
        Theme(top: RGB(26, 20, 70), mid: RGB(98, 44, 112), bot: RGB(255, 128, 92), hue: 26),    // dusk
        Theme(top: RGB(4, 8, 34), mid: RGB(16, 30, 88), bot: RGB(44, 70, 134), hue: 42),        // deep night
        Theme(top: RGB(3, 16, 30), mid: RGB(8, 62, 78), bot: RGB(36, 150, 128), hue: 168),      // aurora
        Theme(top: RGB(20, 5, 44), mid: RGB(80, 16, 98), bot: RGB(204, 60, 128), hue: 322),     // orchid
        Theme(top: RGB(28, 42, 96), mid: RGB(196, 108, 140), bot: RGB(255, 198, 128), hue: 12)  // dawn
    ]

    public var H = 700.0
    public var skinColor = RGB(255, 214, 102)
    public var reduceMotion = false
    public var quickLabel = "QUICK!"
    public var skipLabel = "SKIP!"

    public private(set) var phase: Phase = .menu
    public private(set) var t = 0.0
    public private(set) var score = 0
    public private(set) var combo = 0
    public private(set) var maxIdx = 0
    public private(set) var camY = 0.0
    public private(set) var camStart = 0.0
    public private(set) var shake = 0.0
    public private(set) var pulse = 0.0
    public private(set) var deadT = 0.0
    public private(set) var themeIdx = 0
    public private(set) var skyTop = GameCore.themes[0].top
    public private(set) var skyMid = GameCore.themes[0].mid
    public private(set) var skyBot = GameCore.themes[0].bot

    public private(set) var lanterns: [Lantern] = []
    public private(set) var gems: [Gem] = []
    public private(set) var parts: [Particle] = []
    public private(set) var texts: [FloatText] = []
    public private(set) var trail: [TrailPoint] = []
    private var lanternCount = 0
    private var events: [GameEvent] = []

    // firefly
    public private(set) var px = 0.0
    public private(set) var py = 0.0
    public private(set) var vx = 0.0
    public private(set) var vy = 0.0
    public private(set) var mode: Mode = .orbit
    public private(set) var cur: Lantern!
    public private(set) var angle = 0.0
    public private(set) var dir = 1.0
    public private(set) var orbitR = 30.0
    public private(set) var flyT = 0.0
    public private(set) var turn = 0.0
    private var ignore: Lantern?
    private var quick = false

    public init() { reset() }

    public func drainEvents() -> [GameEvent] { let e = events; events.removeAll(); return e }

    private func rnd(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b) }
    private func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { v < a ? a : (v > b ? b : v) }
    public func difficulty(_ idx: Int) -> Double { min(1, Double(idx) / 50) }

    /// Light left in the firefly: 1 on a lantern, fading to 0 during a flight.
    public var light: Double { mode == .fly ? clampD(1 - flyT / GameCore.maxFlight, 0, 1) : 1 }
    /// Length of the aim guide for the lantern the firefly is on.
    public var aimLength: Double { 240 - difficulty(cur.idx) * 150 }

    private func spawnLantern() {
        let W = GameCore.W
        let last = lanterns.last
        let idx = lanternCount; lanternCount += 1
        let d = difficulty(idx)
        var x = W / 2, y = 0.0
        if let last = last {
            y = last.y - (rnd(132, 172) + d * 46)
            repeat { x = rnd(58, W - 58) } while abs(x - last.bx) < 46
        }
        let r = idx == 0 ? 38 : 36 - d * 9 + rnd(-2, 2)
        let hue = GameCore.themes[(idx / 12) % GameCore.themes.count].hue + rnd(-14, 14)
        let L = Lantern(idx: idx, x: x, y: y, r: r, hue: hue)
        if idx > 6 && Double.random(in: 0..<1) < 0.22 + d * 0.38 {
            L.amp = rnd(18, 30 + d * 26); L.sp = rnd(0.8, 1.3 + d * 0.6)
            L.bx = clampD(L.bx, 58 + L.amp, W - 58 - L.amp)
        }
        lanterns.append(L)
        if let last = last, idx > 2, Double.random(in: 0..<1) < 0.38 {
            gems.append(Gem(x: clampD((last.bx + L.bx) / 2 + rnd(-46, 46), 26, W - 26),
                            y: (last.y + L.y) / 2 + rnd(-18, 18), got: false, ph: rnd(0, 2 * Double.pi)))
        }
    }

    public func reset() {
        lanterns = []; gems = []; parts = []; texts = []; trail = []; lanternCount = 0; events = []
        score = 0; combo = 0; maxIdx = 0; shake = 0; pulse = 0; deadT = 0; themeIdx = 0
        for _ in 0..<8 { spawnLantern() }
        let L = lanterns[0]
        mode = .orbit; cur = L; angle = -Double.pi / 2; dir = 1; orbitR = L.r; flyT = 0; ignore = nil; turn = 0; quick = false
        px = L.x; py = L.y - L.r; vx = 0; vy = 0
        camY = L.y - H * 0.62; camStart = camY
        phase = .menu
    }

    public func start() { reset(); phase = .play }

    /// The one input: let go of the lantern.
    public func tap() {
        guard phase == .play, mode == .orbit else { return }
        let sp = 430 + difficulty(cur.idx) * 120
        vx = dir * sp * -sin(angle); vy = dir * sp * cos(angle)
        ignore = cur; quick = turn < 4.4; mode = .fly; flyT = 0
        events.append(.leap)
    }

    private func burst(_ x: Double, _ y: Double, _ color: RGB, _ n: Int, _ speed: Double) {
        for _ in 0..<n {
            let a = rnd(0, 2 * Double.pi), v = rnd(0.25, 1) * speed
            parts.append(Particle(x: x, y: y, vx: cos(a) * v, vy: sin(a) * v, life: rnd(0.35, 0.9), maxLife: 0.9, color: color, size: rnd(5, 13)))
        }
    }
    private func say(_ x: Double, _ y: Double, _ text: String, _ tone: TextTone, _ size: Double) {
        texts.append(FloatText(x: clampD(x, 60, GameCore.W - 60), y: y, text: text, tone: tone, size: size, life: 1))
    }

    private func capture(_ L: Lantern, _ dist: Double) {
        let rx = px - L.x, ry = py - L.y
        mode = .orbit; cur = L; orbitR = dist; angle = atan2(ry, rx)
        dir = (rx * vy - ry * vx) >= 0 ? 1 : -1
        turn = 0; ignore = nil; L.pop = 1
        let rgb = hslToRgb(L.hue, 100, 68)
        if !L.visited {
            L.visited = true
            let skip = max(0, L.idx - maxIdx - 1)
            combo = quick ? combo + 1 : 0
            let c = min(combo, 4)
            let gain = 1 + c + skip * 2
            score += gain; maxIdx = L.idx; pulse = 1
            themeIdx = (L.idx / 12) % GameCore.themes.count
            burst(px, py, rgb, 16 + c * 5, 190)
            say(L.x, L.y - L.r - 22, "+\(gain)", .ink, Double(22 + c * 3))
            if skip > 0 { say(L.x, L.y - L.r - 48, skipLabel, .jade, 17) }
            else if combo >= 2 { say(L.x, L.y - L.r - 48, "\(quickLabel) ×\(1 + c)", .ember, 16) }
            events.append(.hop(note: combo + (skip > 0 ? 2 : 0)))
        } else {
            burst(px, py, rgb, 6, 110)
            events.append(.rehop)
        }
    }

    private func die(_ why: DeathReason) {
        guard phase == .play else { return }
        phase = .dead; mode = .dead; deadT = 0; shake = reduceMotion ? 0 : 16
        burst(px, py, skinColor, 44, 300); burst(px, py, RGB(255, 255, 255), 14, 160)
        events.append(.died(why))
    }

    public func update(_ dt: Double) {
        let W = GameCore.W
        t += dt
        for L in lanterns {
            if L.amp != 0 { L.x = L.bx + sin(t * L.sp + L.ph) * L.amp }
            if L.pop > 0 { L.pop = max(0, L.pop - dt * 3) }
        }
        if mode == .orbit {
            let L = cur!, d = difficulty(L.idx), w = 3 + d * 1.8
            angle += dir * w * dt; turn += w * dt
            orbitR += (L.r - orbitR) * min(1, dt * 10)
            px = L.x + cos(angle) * orbitR; py = L.y + sin(angle) * orbitR
            if phase == .play && maxIdx > 0 {
                L.fuse -= dt / (6 - d * 2.6)
                if L.fuse <= 0 { L.fuse = 0; L.lit = false; die(.burned) }
            }
        } else if mode == .fly {
            px += vx * dt; py += vy * dt; flyT += dt
            if px < 10 { px = 10; vx = abs(vx); events.append(.wall); burst(px, py, RGB(255, 255, 255), 5, 90) }
            if px > W - 10 { px = W - 10; vx = -abs(vx); events.append(.wall); burst(px, py, RGB(255, 255, 255), 5, 90) }
            if let ig = ignore, hypot(px - ig.x, py - ig.y) > ig.r + 18 { ignore = nil }
            for L in lanterns {
                if !L.lit || L === ignore { continue }
                let dist = hypot(px - L.x, py - L.y)
                if dist < L.r + 12 { capture(L, dist); break }
            }
            if mode == .fly {
                for i in gems.indices where !gems[i].got && hypot(px - gems[i].x, py - gems[i].y) < 24 {
                    gems[i].got = true; score += 2; pulse = 1
                    burst(gems[i].x, gems[i].y, RGB(111, 245, 200), 14, 170)
                    say(gems[i].x, gems[i].y - 16, "+2", .jade, 18)
                    events.append(.gem)
                }
                if flyT > GameCore.maxFlight || py > camY + H + 30 { die(.lost) }
            }
        }
        if mode != .dead {
            trail.append(TrailPoint(x: px, y: py)); if trail.count > 22 { trail.removeFirst() }
        } else if !trail.isEmpty { trail.removeFirst() }

        let anchor = mode == .orbit ? cur.y : min(py + H * 0.15, cur.y)
        camY += (anchor - H * 0.62 - camY) * min(1, dt * 4)
        while lanterns[lanterns.count - 1].y > camY - 500 { spawnLantern() }
        if lanterns.count > 30 { lanterns = lanterns.filter { $0.y < camY + H + 260 || $0 === cur } }
        if gems.count > 30 { gems = gems.filter { $0.y < camY + H + 100 } }

        for i in parts.indices {
            parts[i].x += parts[i].vx * dt; parts[i].y += parts[i].vy * dt
            parts[i].vy += 160 * dt; parts[i].vx *= 0.985; parts[i].life -= dt
        }
        parts.removeAll { $0.life <= 0 }
        for i in texts.indices { texts[i].y -= 34 * dt; texts[i].life -= dt * 0.95 }
        texts.removeAll { $0.life <= 0 }
        shake *= pow(0.004, dt); if shake < 0.05 { shake = 0 }
        pulse = max(0, pulse - dt * 3.2)

        let th = GameCore.themes[themeIdx], k = min(1, dt * 1.2)
        func mix(_ a: inout RGB, _ b: RGB) { a.r += (b.r - a.r) * k; a.g += (b.g - a.g) * k; a.b += (b.b - a.b) * k }
        mix(&skyTop, th.top); mix(&skyMid, th.mid); mix(&skyBot, th.bot)

        if phase == .dead { deadT += dt }
    }
}
