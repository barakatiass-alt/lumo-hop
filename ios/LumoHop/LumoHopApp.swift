import SwiftUI
import SpriteKit

struct Strings {
    let eyebrow, tagline, play, again, tap, best, newBest, share, quick, skip, burned, lost, sound: String
    let shareText: (Int) -> String
    let unlock: (Int) -> String

    static let english = Strings(
        eyebrow: "NIGHT OF LANTERNS", tagline: "One firefly, a sky full of lanterns.\nOne tap sends it to the next light.",
        play: "Tap to start", again: "Tap to go again", tap: "TAP = LEAP", best: "Best", newBest: "New best!",
        share: "Challenge a friend", quick: "QUICK!", skip: "SKIP!", burned: "THE LANTERN BURNED OUT", lost: "LOST IN THE DARK", sound: "Sound",
        shareText: { "I hopped \($0) lanterns in Lumo Hop ✨ bet you can't beat me" },
        unlock: { "Unlocks at best \($0)" })
    static let hebrew = Strings(
        eyebrow: "ליל הפנסים", tagline: "גחלילית אחת, שמיים מלאים פנסים.\nנגיעה אחת משחררת אותה אל הפנס הבא.",
        play: "נגיעה כדי להתחיל", again: "נגיעה לסיבוב נוסף", tap: "נגיעה = קפיצה", best: "שיא", newBest: "שיא חדש!",
        share: "לאתגר חבר", quick: "מהיר!", skip: "דילוג!", burned: "הפנס נשרף", lost: "הלכה לאיבוד בחושך", sound: "צליל",
        shareText: { "קפצתי \($0) פנסים ב-Lumo Hop ✨ נראה אותך עובר אותי" },
        unlock: { "נפתח בשיא \($0)" })
    static var current: Strings { (Locale.preferredLanguages.first ?? "en").hasPrefix("he") ? hebrew : english }
}

struct Skin { let color: RGB; let need: Int }

final class GameModel: ObservableObject {
    enum Screen { case menu, playing, over }
    static let skins: [Skin] = [
        Skin(color: RGB(255, 214, 102), need: 0), Skin(color: RGB(120, 230, 255), need: 15), Skin(color: RGB(255, 130, 205), need: 40),
        Skin(color: RGB(150, 255, 150), need: 90), Skin(color: RGB(255, 255, 255), need: 160)
    ]

    @Published var screen: Screen = .menu
    @Published var score = 0
    @Published var best = UserDefaults.standard.integer(forKey: "best")
    @Published var newBest = false
    @Published var reason: DeathReason = .lost
    @Published var skin = 0 { didSet { UserDefaults.standard.set(skin, forKey: "skin") } }
    @Published var muted = UserDefaults.standard.bool(forKey: "muted") {
        didSet { UserDefaults.standard.set(muted, forKey: "muted"); scene.synth.muted = muted }
    }
    let strings = Strings.current
    private var overShownAt = Date.distantPast

    lazy var scene: GameScene = {
        let s = GameScene(size: CGSize(width: 390, height: 844))
        s.scaleMode = .resizeFill
        s.model = self
        return s
    }()

    init() {
        let saved = UserDefaults.standard.integer(forKey: "skin")
        if saved > 0, saved < GameModel.skins.count, GameModel.skins[saved].need <= best { skin = saved }
    }

    var overlayVisible: Bool { screen != .playing }

    func start() {
        if screen == .over && Date().timeIntervalSince(overShownAt) < 0.35 { return }
        scene.startGame()
        screen = .playing
    }
    /// Called at the moment of death; the game-over card appears a beat later.
    func runEnded(score: Int, reason: DeathReason) {
        self.score = score; self.reason = reason
        newBest = score > best
        if newBest { best = score; UserDefaults.standard.set(best, forKey: "best") }
    }
    func showGameOver() { overShownAt = Date(); screen = .over }
}

@main
struct LumoHopApp: App {
    @StateObject private var model = GameModel()
    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

private extension Color {
    static let ink = Color(red: 1, green: 243 / 255, blue: 214 / 255)
    static let ember = Color(red: 1, green: 179 / 255, blue: 71 / 255)
    static let flame = Color(red: 1, green: 106 / 255, blue: 61 / 255)
    static let jade = Color(red: 111 / 255, green: 245 / 255, blue: 200 / 255)
    static let night = Color(red: 7 / 255, green: 11 / 255, blue: 36 / 255)
    init(_ c: RGB) { self.init(red: c.r / 255, green: c.g / 255, blue: c.b / 255) }
}

struct RootView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
            if model.screen != .playing {
                MenuOverlay(model: model).transition(.opacity)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { model.muted.toggle() } label: {
                        Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.ink.opacity(model.muted ? 0.45 : 1))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.night.opacity(0.55)))
                            .overlay(Circle().stroke(Color.ink.opacity(0.25), lineWidth: 1))
                    }
                    .accessibilityLabel(model.strings.sound)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.3), value: model.screen)
    }
}

struct MenuOverlay: View {
    @ObservedObject var model: GameModel
    @State private var hint = ""
    @State private var breathe = false

    var body: some View {
        let t = model.strings
        ZStack {
            RadialGradient(colors: [Color.night.opacity(0.35), Color.night.opacity(0.8)], center: .center, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { model.start() }

            VStack(spacing: 18) {
                Text(model.screen == .over ? (model.reason == .burned ? t.burned : t.lost) : t.eyebrow)
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(3.5)
                    .foregroundColor(Color.jade)

                if model.screen == .over {
                    VStack(spacing: 2) {
                        Text("\(model.score)")
                            .font(.system(size: 130, weight: .black, design: .rounded)).monospacedDigit()
                            .foregroundColor(Color.ink)
                            .shadow(color: Color.ember.opacity(0.8), radius: 18).shadow(color: Color.flame.opacity(0.5), radius: 44)
                        Text(model.newBest ? t.newBest : "\(t.best): \(model.best)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(model.newBest ? Color.jade : Color.ink.opacity(0.62))
                    }
                } else {
                    VStack(spacing: -10) {
                        Text("LUMO").font(.system(size: 84, weight: .black, design: .rounded)).foregroundColor(Color.ink)
                        Text("HOP").font(.system(size: 52, weight: .black, design: .rounded)).tracking(16).foregroundColor(Color.ember)
                    }
                    .shadow(color: Color.ember.opacity(0.75), radius: 16).shadow(color: Color.flame.opacity(0.5), radius: 44)
                    Text(model.best > 0 ? "\(t.best): \(model.best)" : t.tagline)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center).foregroundColor(Color.ink.opacity(0.62))
                }

                HStack(spacing: 12) {
                    ForEach(0..<GameModel.skins.count, id: \.self) { i in
                        let skin = GameModel.skins[i], locked = skin.need > model.best
                        Button {
                            if locked { hint = t.unlock(skin.need) } else { model.skin = i; hint = "" }
                        } label: {
                            ZStack {
                                Circle().fill(Color.night.opacity(0.55))
                                if locked {
                                    Text("\(skin.need)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(Color.ink.opacity(0.62))
                                } else {
                                    Circle().fill(Color(skin.color)).frame(width: 18, height: 18).shadow(color: Color(skin.color), radius: 7)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.ink.opacity(i == model.skin ? 1 : 0), lineWidth: 2))
                        }
                        .accessibilityLabel(locked ? t.unlock(skin.need) : "Firefly \(i + 1)")
                    }
                }
                Text(hint).font(.system(size: 12, design: .rounded)).foregroundColor(Color.ink.opacity(0.62)).frame(height: 14)

                Text(model.screen == .over ? t.again : t.play)
                    .font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(Color.ember)
                    .opacity(breathe ? 0.45 : 1)
                    .allowsHitTesting(false)

                if model.screen == .over {
                    ShareLink(item: t.shareText(model.score)) {
                        Text(t.share)
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Color.ink)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Capsule().fill(Color.night.opacity(0.55)))
                            .overlay(Capsule().stroke(Color.ink.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
