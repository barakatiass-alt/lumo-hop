import SpriteKit
import UIKit

extension UIColor {
    convenience init(_ c: RGB, alpha: CGFloat = 1) {
        self.init(red: CGFloat(c.r / 255), green: CGFloat(c.g / 255), blue: CGFloat(c.b / 255), alpha: alpha)
    }
}

enum Palette {
    static let ink = UIColor(RGB(255, 243, 214))
    static let ember = UIColor(RGB(255, 179, 71))
    static let jade = UIColor(RGB(111, 245, 200))
    static let silhouette = UIColor(RGB(6, 8, 24))
}

/// Every picture in the game is painted in code, once, and reused as a texture.
enum Tex {
    private static let space = CGColorSpaceCreateDeviceRGB()

    private static func image(_ w: CGFloat, _ h: CGFloat, scale: CGFloat = 2, _ draw: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = scale; f.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f).image { draw($0.cgContext) }
    }
    private static func gradient(_ stops: [(CGFloat, UIColor)]) -> CGGradient {
        let colors = stops.map { $0.1.cgColor } as CFArray
        let locations = stops.map { $0.0 }
        return CGGradient(colorsSpace: space, colors: colors, locations: locations)!
    }

    /// Soft white light; sprites tint it and add it onto the scene.
    static let glow: SKTexture = {
        let img = image(128, 128, scale: 1) { c in
            let g = gradient([(0, UIColor(white: 1, alpha: 1)), (0.25, UIColor(white: 1, alpha: 0.55)),
                              (0.6, UIColor(white: 1, alpha: 0.14)), (1, UIColor(white: 1, alpha: 0))])
            c.drawRadialGradient(g, startCenter: CGPoint(x: 64, y: 64), startRadius: 0, endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
        return SKTexture(image: img)
    }()

    static let dot: SKTexture = {
        SKTexture(image: image(16, 16) { c in
            c.setFillColor(UIColor.white.cgColor); c.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        })
    }()

    static let wing: SKTexture = {
        SKTexture(image: image(16, 6) { c in
            c.setFillColor(UIColor(white: 1, alpha: 0.55).cgColor); c.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 6))
        })
    }()

    static let gem: SKTexture = {
        SKTexture(image: image(24, 24) { c in
            c.translateBy(x: 12, y: 12)
            let p = UIBezierPath()
            for i in 0..<8 {
                let a = CGFloat(i) / 8 * 2 * .pi, rr: CGFloat = i % 2 == 1 ? 4 : 11
                let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.close()
            c.setFillColor(UIColor(RGB(234, 255, 247)).cgColor); c.addPath(p.cgPath); c.fillPath()
        })
    }()

    static let moon: SKTexture = {
        SKTexture(image: image(300, 300) { c in
            let mid = CGPoint(x: 150, y: 150)
            let halo = gradient([(0, UIColor(RGB(255, 236, 190), alpha: 0.5)), (0.3, UIColor(RGB(255, 236, 190), alpha: 0.22)),
                                 (1, UIColor(RGB(255, 236, 190), alpha: 0))])
            c.drawRadialGradient(halo, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: 150, options: [])
            c.saveGState()
            c.addEllipse(in: CGRect(x: 112, y: 112, width: 76, height: 76)); c.clip()
            let disc = gradient([(0, UIColor(RGB(255, 253, 242))), (1, UIColor(RGB(255, 226, 166)))])
            c.drawRadialGradient(disc, startCenter: CGPoint(x: 140, y: 140), startRadius: 4, endCenter: mid, endRadius: 40, options: [.drawsAfterEndLocation])
            c.restoreGState()
            c.setFillColor(UIColor(RGB(214, 170, 110), alpha: 0.28).cgColor)
            for (dx, dy, r) in [(-12.0, -8.0, 8.0), (12, 10, 6), (4, -18, 4), (-16, 14, 5)] {
                c.fillEllipse(in: CGRect(x: 150 + dx - r, y: 150 + dy - r, width: r * 2, height: r * 2))
            }
        })
    }()

    /// Shoreline with palms. The horizon sits 110 units below the top edge of the picture.
    static let shoreHorizon: CGFloat = 110
    static let shoreSize = CGSize(width: 400, height: 340)
    static let shore: SKTexture = {
        SKTexture(image: image(shoreSize.width, shoreSize.height) { c in
            let gy = shoreHorizon, W = shoreSize.width
            let sea = gradient([(0, UIColor(RGB(255, 190, 130), alpha: 0.38)), (0.12, UIColor(RGB(20, 24, 70), alpha: 0.85)), (0.7, UIColor(RGB(6, 8, 28)))])
            c.saveGState(); c.clip(to: CGRect(x: 0, y: gy, width: W, height: shoreSize.height - gy))
            c.drawLinearGradient(sea, start: CGPoint(x: 0, y: gy), end: CGPoint(x: 0, y: gy + 230), options: [.drawsAfterEndLocation])
            c.restoreGState()
            c.setFillColor(UIColor(RGB(255, 226, 166), alpha: 0.3).cgColor)
            for i in 0..<9 { let ww = CGFloat(46 - i * 4); c.fill(CGRect(x: W * 0.77 - ww / 2, y: gy + 10 + CGFloat(i) * 9, width: ww, height: 2)) }

            c.setFillColor(Palette.silhouette.cgColor); c.setStrokeColor(Palette.silhouette.cgColor)
            let left = UIBezierPath()
            left.move(to: CGPoint(x: -10, y: gy + 40))
            left.addQuadCurve(to: CGPoint(x: 150, y: gy + 18), controlPoint: CGPoint(x: 60, y: gy - 34))
            left.addQuadCurve(to: CGPoint(x: 210, y: gy + 230), controlPoint: CGPoint(x: 190, y: gy + 34))
            left.addLine(to: CGPoint(x: -10, y: gy + 230)); left.close()
            c.addPath(left.cgPath); c.fillPath()
            let right = UIBezierPath()
            right.move(to: CGPoint(x: W + 10, y: gy + 30))
            right.addQuadCurve(to: CGPoint(x: W - 120, y: gy + 40), controlPoint: CGPoint(x: W - 50, y: gy - 8))
            right.addLine(to: CGPoint(x: W - 100, y: gy + 230)); right.addLine(to: CGPoint(x: W + 10, y: gy + 230)); right.close()
            c.addPath(right.cgPath); c.fillPath()

            func palm(_ x: CGFloat, _ base: CGFloat, _ h: CGFloat, _ lean: CGFloat) {
                c.setLineCap(.round)
                let trunk = UIBezierPath()
                trunk.move(to: CGPoint(x: x, y: base))
                trunk.addQuadCurve(to: CGPoint(x: x + lean, y: base - h), controlPoint: CGPoint(x: x + lean * 0.25, y: base - h * 0.6))
                c.setLineWidth(5); c.addPath(trunk.cgPath); c.strokePath()
                let tx = x + lean, ty = base - h, len = h * 0.5
                c.setLineWidth(3.2)
                for i in 0..<7 {
                    let a = -CGFloat.pi * (0.04 + CGFloat(i) / 6 * 0.92)
                    let frond = UIBezierPath()
                    frond.move(to: CGPoint(x: tx, y: ty))
                    frond.addQuadCurve(to: CGPoint(x: tx + cos(a) * len, y: ty + sin(a) * len * 0.5 + len * 0.42),
                                       controlPoint: CGPoint(x: tx + cos(a) * len * 0.62, y: ty + sin(a) * len * 0.75))
                    c.addPath(frond.cgPath); c.strokePath()
                }
            }
            palm(46, gy + 6, 104, 22); palm(92, gy - 4, 74, -16); palm(W - 44, gy + 16, 88, -20)
        })
    }()

    /// Paper lantern, painted for an orbit radius of 36 on a square of 2.4 radii.
    static let lanternBaseR: CGFloat = 36
    private static var lanternCache: [Int: SKTexture] = [:]
    static func lantern(hue: Double, lit: Bool) -> SKTexture {
        let step = Int((pmod(hue, 360) / 6).rounded())
        let key = lit ? step : -1
        if let t = lanternCache[key] { return t }
        let r = lanternBaseR, side = r * 2.4, h = Double(step) * 6
        let img = image(side, side, scale: 3) { c in
            c.translateBy(x: side / 2, y: side / 2)
            let tw = r * 0.56, bw = r * 0.34, hh = r * 0.62
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -bw, y: hh))
            p.addCurve(to: CGPoint(x: 0, y: -hh * 1.06), controlPoint1: CGPoint(x: -tw * 1.2, y: hh * 0.15), controlPoint2: CGPoint(x: -tw * 1.12, y: -hh))
            p.addCurve(to: CGPoint(x: bw, y: hh), controlPoint1: CGPoint(x: tw * 1.12, y: -hh), controlPoint2: CGPoint(x: tw * 1.2, y: hh * 0.15))
            p.close()
            c.saveGState(); c.addPath(p.cgPath); c.clip()
            if lit {
                let g = gradient([(0, UIColor(RGB(255, 251, 224))), (0.3, UIColor(hslToRgb(h + 22, 100, 70))),
                                  (0.75, UIColor(hslToRgb(h, 96, 56))), (1, UIColor(hslToRgb(h - 14, 90, 40)))])
                c.drawRadialGradient(g, startCenter: CGPoint(x: 0, y: r * 0.42), startRadius: 1, endCenter: CGPoint(x: 0, y: r * 0.1), endRadius: r * 0.95,
                                     options: [.drawsAfterEndLocation])
            } else {
                c.setFillColor(UIColor(RGB(70, 74, 110), alpha: 0.55).cgColor); c.fill(CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
            }
            c.restoreGState()
            c.setStrokeColor((lit ? UIColor(RGB(120, 40, 10), alpha: 0.22) : UIColor(white: 0, alpha: 0.25)).cgColor); c.setLineWidth(1)
            for s in [CGFloat(-1), 1] {
                let rib = UIBezierPath()
                rib.move(to: CGPoint(x: s * r * 0.13, y: r * 0.6))
                rib.addQuadCurve(to: CGPoint(x: s * r * 0.1, y: -r * 0.62), controlPoint: CGPoint(x: s * r * 0.3, y: -r * 0.2))
                c.addPath(rib.cgPath); c.strokePath()
            }
            c.setFillColor((lit ? UIColor(RGB(90, 30, 10), alpha: 0.6) : UIColor(RGB(20, 20, 40), alpha: 0.7)).cgColor)
            c.fill(CGRect(x: -r * 0.36, y: r * 0.58, width: r * 0.72, height: 3))
        }
        let t = SKTexture(image: img)
        lanternCache[key] = t
        return t
    }

    /// Three-stop vertical sky, top to bottom.
    static func sky(top: RGB, mid: RGB, bot: RGB) -> SKTexture {
        let img = image(2, 256, scale: 1) { c in
            let g = gradient([(0, UIColor(top)), (0.58, UIColor(mid)), (1, UIColor(bot))])
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
        return SKTexture(image: img)
    }
}
