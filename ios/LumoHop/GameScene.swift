import SpriteKit
import UIKit

/// One lantern on screen: orbit ring, halo, paper body and flame. Children are sized in logical units; the node itself is scaled.
private final class LanternNode: SKNode {
    private let ring: SKShapeNode
    private let halo = SKSpriteNode(texture: Tex.glow)
    private let body = SKSpriteNode(texture: Tex.glow)
    private let flame = SKSpriteNode(texture: Tex.glow)
    private var shownLit: Bool?

    init(_ l: Lantern) {
        let rr = CGFloat(l.r)
        let circle = CGPath(ellipseIn: CGRect(x: -rr, y: -rr, width: rr * 2, height: rr * 2), transform: nil)
        ring = SKShapeNode(path: circle.copy(dashingWithPhase: 0, lengths: [3, 8]))
        super.init()
        ring.lineWidth = 1.4; ring.fillColor = .clear; ring.zPosition = 0
        halo.blendMode = .add; halo.colorBlendFactor = 1; halo.zPosition = 1
        body.zPosition = 2
        flame.blendMode = .add; flame.color = UIColor(RGB(255, 240, 180)); flame.colorBlendFactor = 1; flame.zPosition = 3
        addChild(ring); addChild(halo); addChild(body); addChild(flame)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("not used") }

    func sync(_ l: Lantern, t: Double) {
        if shownLit != l.lit {
            shownLit = l.lit
            body.texture = Tex.lantern(hue: l.hue, lit: l.lit)
            halo.isHidden = !l.lit; flame.isHidden = !l.lit
            halo.color = UIColor(hslToRgb(l.hue, 100, 62))
            ring.strokeColor = Palette.ink.withAlphaComponent(l.lit ? 0.3 : 0.08)
        }
        let r = CGFloat(l.r) * (1 + CGFloat(l.pop) * 0.14)
        body.size = CGSize(width: r * 2.4, height: r * 2.4)
        body.zRotation = CGFloat(sin(t * 0.9 + l.sway) * 0.07)
        halo.size = CGSize(width: r * 4.6, height: r * 4.6)
        halo.alpha = 0.5 + CGFloat(l.pop) * 0.3
        let fs = r * CGFloat(1 + 0.15 * sin(t * 9 + l.sway))
        flame.size = CGSize(width: fs, height: fs); flame.alpha = 0.8
        flame.position = CGPoint(x: 0, y: -r * 0.5)
        ring.zRotation = CGFloat(t * 0.5 + l.sway)
    }
}

final class GameScene: SKScene {
    let core = GameCore()
    weak var model: GameModel?
    let synth = Synth()

    private var s: CGFloat = 1            // screen points per logical unit
    private var built = false
    private var lastTime: TimeInterval = 0
    private var reportedOver = false
    private var shakeX = 0.0, shakeY = 0.0

    private let skyNode = SKSpriteNode()
    private var skyKey = ""
    private var starNodes: [SKSpriteNode] = []
    private var starData: [(x: Double, y: Double, s: Double, ph: Double, sp: Double)] = []
    private let moonNode = SKSpriteNode(texture: Tex.moon)
    private var bokehNodes: [SKSpriteNode] = []
    private var bokehData: [(x: Double, y: Double, s: Double, sp: Double, ph: Double)] = []
    private let shoreNode = SKSpriteNode(texture: Tex.shore)
    private var lanternNodes: [Int: LanternNode] = [:]
    private var gemNodes: [SKSpriteNode] = []
    private var gemGlows: [SKSpriteNode] = []
    private var aimNodes: [SKSpriteNode] = []
    private var trailNodes: [SKSpriteNode] = []
    private var partNodes: [SKSpriteNode] = []
    private var textNodes: [SKLabelNode] = []
    private let fuseNode = SKShapeNode()
    private let fly = SKNode()
    private let flyGlow = SKSpriteNode(texture: Tex.glow)
    private let flyCore = SKSpriteNode(texture: Tex.dot)
    private let wingA = SKSpriteNode(texture: Tex.wing)
    private let wingB = SKSpriteNode(texture: Tex.wing)
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()

    // MARK: setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(RGB(7, 11, 36))
        if !built { build() }
        layout()
    }
    override func didChangeSize(_ oldSize: CGSize) { if built { layout() } }

    private func glowSprite(z: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(texture: Tex.glow)
        n.blendMode = .add; n.colorBlendFactor = 1; n.zPosition = z; n.isHidden = true
        addChild(n); return n
    }

    private func build() {
        built = true
        skyNode.zPosition = -100; skyNode.anchorPoint = CGPoint(x: 0, y: 0); addChild(skyNode)
        for _ in 0..<90 {
            starData.append((Double.random(in: 0...400), Double.random(in: 0...1), Double.random(in: 0.5...1.7), Double.random(in: 0...6.28), Double.random(in: 0.6...2.2)))
            let n = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1)); n.zPosition = -90; addChild(n); starNodes.append(n)
        }
        moonNode.zPosition = -80; addChild(moonNode)
        for _ in 0..<13 {
            bokehData.append((Double.random(in: 0...400), Double.random(in: 0...1), Double.random(in: 5...12), Double.random(in: 4...12), Double.random(in: 0...6.28)))
            let n = glowSprite(z: -70)
            n.color = UIColor(hslToRgb(Double.random(in: 15...45), 100, 62)); n.alpha = 0.4; n.isHidden = false
            bokehNodes.append(n)
        }
        shoreNode.zPosition = -60; shoreNode.anchorPoint = CGPoint(x: 0.5, y: 1); addChild(shoreNode)

        for _ in 0..<12 {
            let g = glowSprite(z: 14); g.color = Palette.jade; gemGlows.append(g)
            let n = SKSpriteNode(texture: Tex.gem); n.zPosition = 15; n.isHidden = true; addChild(n); gemNodes.append(n)
        }
        for _ in 0..<18 {
            let n = SKSpriteNode(texture: Tex.dot); n.color = Palette.ink; n.colorBlendFactor = 1; n.zPosition = 18; n.isHidden = true
            addChild(n); aimNodes.append(n)
        }
        for _ in 0..<22 { trailNodes.append(glowSprite(z: 20)) }
        for _ in 0..<170 { partNodes.append(glowSprite(z: 30)) }
        for _ in 0..<8 {
            let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            l.verticalAlignmentMode = .center; l.horizontalAlignmentMode = .center; l.zPosition = 40; l.isHidden = true
            addChild(l); textNodes.append(l)
        }
        fuseNode.zPosition = 12; fuseNode.fillColor = .clear; fuseNode.lineCap = .round; fuseNode.isHidden = true; addChild(fuseNode)

        fly.zPosition = 22; addChild(fly)
        flyGlow.blendMode = .add; flyGlow.colorBlendFactor = 1; flyGlow.zPosition = 0
        wingA.zPosition = 1; wingB.zPosition = 1; flyCore.zPosition = 2
        wingA.anchorPoint = CGPoint(x: 0.7, y: 0.5); wingB.anchorPoint = CGPoint(x: 0.7, y: 0.5)
        fly.addChild(flyGlow); fly.addChild(wingA); fly.addChild(wingB); fly.addChild(flyCore)

        for l in [scoreLabel, comboLabel, hintLabel] {
            l.verticalAlignmentMode = .center; l.horizontalAlignmentMode = .center; l.zPosition = 50; l.isHidden = true; addChild(l)
        }
        scoreLabel.fontColor = Palette.ink; comboLabel.fontColor = Palette.ember; hintLabel.fontColor = Palette.ink
        lightImpact.prepare(); softImpact.prepare()
    }

    private func layout() {
        guard size.width > 0, size.height > 0 else { return }
        s = size.width / CGFloat(GameCore.W)
        core.H = Double(size.height / s)
        if core.phase == .menu { core.reset() }
        skyNode.size = size; skyNode.position = .zero
        moonNode.size = CGSize(width: 300 * s, height: 300 * s)
        moonNode.position = CGPoint(x: size.width * 0.77, y: size.height * (1 - 0.17))
    }

    // MARK: control

    func startGame() {
        if let m = model {
            core.skinColor = GameModel.skins[m.skin].color
            core.quickLabel = m.strings.quick; core.skipLabel = m.strings.skip
            synth.muted = m.muted
        }
        core.reduceMotion = UIAccessibility.isReduceMotionEnabled
        synth.start()
        core.start()
        reportedOver = false
        lastTime = 0
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if core.phase == .play { core.tap(); handleEvents() }
    }

    private func handleEvents() {
        for e in core.drainEvents() {
            switch e {
            case .hop(let note): synth.hop(note); lightImpact.impactOccurred()
            case .rehop: synth.rehop(); softImpact.impactOccurred()
            case .leap: synth.leap()
            case .wall: synth.wall(); softImpact.impactOccurred()
            case .gem: synth.gem(); lightImpact.impactOccurred()
            case .died(let why):
                synth.dead(); notify.notificationOccurred(.error)
                model?.runEnded(score: core.score, reason: why)
            }
        }
    }

    // MARK: frame

    override func update(_ currentTime: TimeInterval) {
        guard built else { return }
        var dt = lastTime == 0 ? 1.0 / 60 : min(0.034, currentTime - lastTime)
        lastTime = currentTime
        if dt < 0 { dt = 0 }
        if core.phase == .dead && core.deadT < 0.5 { dt *= 0.45 }
        core.update(dt)
        handleEvents()
        if core.phase == .dead && core.deadT > 0.95 && !reportedOver { reportedOver = true; model?.showGameOver() }
        render()
    }

    /// Logical world point to scene point.
    private func pt(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x + shakeX) * s, y: size.height - CGFloat(y - core.camY + shakeY) * s)
    }
    /// Logical point measured from the top of the screen to scene point.
    private func screenPt(_ x: Double, _ yFromTop: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * s, y: size.height - CGFloat(yFromTop) * s)
    }
    private func square(_ side: Double) -> CGSize { CGSize(width: CGFloat(side) * s, height: CGFloat(side) * s) }

    private func render() {
        let t = core.t, H = core.H, camY = core.camY
        shakeX = core.shake > 0 ? Double.random(in: -core.shake...core.shake) : 0
        shakeY = core.shake > 0 ? Double.random(in: -core.shake...core.shake) : 0

        // sky
        let key = "\(Int(core.skyTop.r)),\(Int(core.skyTop.g)),\(Int(core.skyTop.b)),\(Int(core.skyBot.r)),\(Int(core.skyBot.g)),\(Int(core.skyBot.b))"
        if key != skyKey { skyKey = key; skyNode.texture = Tex.sky(top: core.skyTop, mid: core.skyMid, bot: core.skyBot) }

        for (i, d) in starData.enumerated() {
            let y = pmod(d.y * H - camY * 0.05, H)
            let n = starNodes[i]
            n.position = screenPt(d.x, y); n.size = square(d.s)
            n.alpha = CGFloat((0.35 + 0.65 * abs(sin(t * d.sp + d.ph))) * (1 - y / H * 0.7))
        }
        for (i, d) in bokehData.enumerated() {
            let y = pmod(d.y * (H + 120) - camY * 0.28 - t * d.sp, H + 120) - 60
            let n = bokehNodes[i]
            n.position = screenPt(d.x + sin(t * 0.4 + d.ph) * 10, y); n.size = square(d.s * 6)
        }
        let gy = H - 118 + (core.camStart - camY) * 0.55
        shoreNode.isHidden = gy > H + 220
        if !shoreNode.isHidden {
            shoreNode.size = CGSize(width: Tex.shoreSize.width * s, height: Tex.shoreSize.height * s)
            shoreNode.position = screenPt(GameCore.W / 2, gy - Double(Tex.shoreHorizon))
        }

        // lanterns
        var alive = Set<Int>()
        for l in core.lanterns where l.y > camY - 90 && l.y < camY + H + 90 {
            alive.insert(l.idx)
            let node: LanternNode
            if let n = lanternNodes[l.idx] { node = n } else {
                node = LanternNode(l); node.zPosition = 8; addChild(node); lanternNodes[l.idx] = node
            }
            node.position = pt(l.x, l.y + sin(t * 1.3 + l.sway) * 2.5)
            node.setScale(s)
            node.sync(l, t: t)
        }
        for (idx, node) in lanternNodes where !alive.contains(idx) { node.removeFromParent(); lanternNodes[idx] = nil }

        // fuse ring on the lantern the firefly is on
        let cur = core.cur!
        if core.phase == .play && core.mode == .orbit && core.maxIdx > 0 && cur.lit && cur.fuse < 1 {
            let hot = cur.fuse < 0.35
            let path = CGMutablePath(), rad = CGFloat(cur.r + 9) * s, steps = max(2, Int(48 * cur.fuse))
            for i in 0...steps {
                let a = CGFloat.pi / 2 - CGFloat(i) / CGFloat(steps) * 2 * .pi * CGFloat(cur.fuse)
                let p = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            fuseNode.path = path
            fuseNode.position = pt(cur.x, cur.y)
            fuseNode.lineWidth = (hot ? 4 : 3) * s
            fuseNode.strokeColor = hot ? UIColor(RGB(255, 90 + 60 * sin(t * 20), 70), alpha: 0.95) : Palette.ink.withAlphaComponent(0.8)
            fuseNode.isHidden = false
        } else { fuseNode.isHidden = true }

        // gems
        var gi = 0
        for g in core.gems where !g.got && g.y > camY - 40 && g.y < camY + H + 40 && gi < gemNodes.count {
            let n = gemNodes[gi], glow = gemGlows[gi]
            let size = (9 + sin(t * 4 + g.ph) * 1.5) / 11 * 24
            n.isHidden = false; n.position = pt(g.x, g.y); n.size = square(size); n.zRotation = CGFloat(-(t * 1.2 + g.ph))
            glow.isHidden = false; glow.position = n.position; glow.size = square(54); glow.alpha = 0.6
            gi += 1
        }
        while gi < gemNodes.count { gemNodes[gi].isHidden = true; gemGlows[gi].isHidden = true; gi += 1 }

        // aim guide
        var ai = 0
        if core.phase == .play && core.mode == .orbit {
            let len = core.aimLength
            var x = core.px, y = core.py
            var dx = core.dir * -sin(core.angle)
            let dy = core.dir * cos(core.angle)
            var d = 14.0
            while d < len && ai < aimNodes.count {
                x += dx * 14; y += dy * 14
                if x < 10 { x = 20 - x; dx = -dx }
                if x > GameCore.W - 10 { x = 2 * (GameCore.W - 10) - x; dx = -dx }
                let n = aimNodes[ai]
                n.isHidden = false; n.position = pt(x, y); n.size = square(4.4); n.alpha = CGFloat(0.5 * (1 - d / len))
                ai += 1; d += 14
            }
        }
        while ai < aimNodes.count { aimNodes[ai].isHidden = true; ai += 1 }

        // firefly and its trail
        let skin = UIColor(core.skinColor), light = core.light
        let trail = core.trail
        for (i, n) in trailNodes.enumerated() {
            if i < trail.count {
                let k = Double(i) / Double(max(1, trail.count))
                n.isHidden = false; n.color = skin; n.position = pt(trail[i].x, trail[i].y)
                n.size = square(8 + k * 22); n.alpha = CGFloat(k * 0.5 * light)
            } else { n.isHidden = true }
        }
        fly.isHidden = core.mode == .dead
        if !fly.isHidden {
            fly.position = pt(core.px, core.py)
            let heading = core.mode == .fly ? atan2(core.vy, core.vx) : core.angle + core.dir * Double.pi / 2
            fly.zRotation = CGFloat(-heading)
            flyGlow.color = skin
            flyGlow.size = square((60 + sin(t * 12) * 6) * (0.45 + 0.55 * light))
            flyCore.size = square(9.2)
            let flap = CGFloat(0.9 + sin(t * 46) * 0.5)
            wingA.size = CGSize(width: 16 * s, height: 6 * s); wingB.size = wingA.size
            wingA.zRotation = flap; wingB.zRotation = -flap
        }

        // sparks
        let parts = core.parts
        for (i, n) in partNodes.enumerated() {
            if i < parts.count {
                let q = parts[i]
                n.isHidden = false; n.color = UIColor(q.color); n.position = pt(q.x, q.y)
                n.size = square(q.size * 2.4); n.alpha = CGFloat(max(0, min(1, q.life / q.maxLife)))
            } else { n.isHidden = true }
        }

        // floating score texts
        let texts = core.texts
        for (i, l) in textNodes.enumerated() {
            if i < texts.count {
                let q = texts[i]
                l.isHidden = false; l.text = q.text; l.fontSize = CGFloat(q.size) * s; l.position = pt(q.x, q.y)
                l.alpha = CGFloat(max(0, min(1, q.life * 1.6)))
                switch q.tone { case .ink: l.fontColor = Palette.ink; case .jade: l.fontColor = Palette.jade; case .ember: l.fontColor = Palette.ember }
            } else { l.isHidden = true }
        }

        // score, combo, first-run hint
        let overlayUp = model?.overlayVisible ?? true
        let showHud = core.phase == .play || (core.phase == .dead && !overlayUp)
        let top = Double((view?.safeAreaInsets.top ?? 0) / s)
        scoreLabel.isHidden = !showHud
        if showHud {
            scoreLabel.text = "\(core.score)"
            scoreLabel.fontSize = 64 * s * CGFloat(1 + core.pulse * 0.25)
            scoreLabel.position = screenPt(GameCore.W / 2, top + 58)
        }
        comboLabel.isHidden = !(core.phase == .play && core.combo >= 1)
        if !comboLabel.isHidden {
            comboLabel.text = "×\(1 + min(core.combo, 4))"; comboLabel.fontSize = 17 * s
            comboLabel.position = screenPt(GameCore.W / 2, top + 102)
        }
        hintLabel.isHidden = !(core.phase == .play && core.maxIdx == 0 && core.mode == .orbit)
        if !hintLabel.isHidden {
            hintLabel.text = model?.strings.tap ?? "TAP = LEAP"; hintLabel.fontSize = 24 * s
            hintLabel.alpha = CGFloat(0.6 + 0.4 * sin(t * 5))
            hintLabel.position = pt(GameCore.W / 2, cur.y + 92)
        }
    }
}
