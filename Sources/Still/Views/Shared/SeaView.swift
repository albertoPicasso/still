import SwiftUI

// El mar de Still: un barquito con un bichito pescando. La escena cambia con el estado:
// calma (libre), mar movido (desplegando) y temporal (algo falló).
struct SeaView: View {
    let mood: Double
    let night: Bool

    @State private var smoother = Smoother()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let (t, a) = smoother.step(to: mood, at: tl.date.timeIntervalSinceReferenceDate)
                SeaScene.draw(in: &ctx, size: size, t: t, params: SeaParams.at(a, night: night), night: night)
            }
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}

// Suaviza el paso entre estados y da el tiempo de la animación desde que aparece
final class Smoother {
    private var value = 0.0
    private var last: Double?
    private var start: Double?

    func step(to target: Double, at now: Double) -> (t: Double, a: Double) {
        guard let last, let start else {
            self.last = now; self.start = now; value = target
            return (0, target)
        }
        let dt = min(0.2, max(0, now - last))
        value += (target - value) * min(1, dt * 1.6)
        self.last = now
        return (now - start, value)
    }
}

struct SeaParams {
    var amp, speed, sun, cloud, rain, dark, roll, effort, panic, light: Double
    var skyTop, skyBottom: [Double]

    static func at(_ a: Double, night: Bool) -> SeaParams {
        a <= 0.5
            ? mix(calm(night), busy(night), a * 2)
            : mix(busy(night), storm(night), (a - 0.5) * 2)
    }

    private static func calm(_ n: Bool) -> SeaParams {
        SeaParams(amp: 4, speed: 0.6, sun: 1, cloud: 0.3, rain: 0, dark: 0, roll: 2, effort: 0, panic: 0, light: 0,
                  skyTop: rgb(n ? 0x0E2A3A : 0xBFE3EC), skyBottom: rgb(n ? 0x1F4E63 : 0xF0F7F4))
    }
    private static func busy(_ n: Bool) -> SeaParams {
        SeaParams(amp: 9, speed: 1.2, sun: 0.5, cloud: 0.75, rain: 0, dark: 0.25, roll: 7, effort: 1, panic: 0, light: 0,
                  skyTop: rgb(n ? 0x14293A : 0xC6D6D6), skyBottom: rgb(n ? 0x3A4D58 : 0xF3E4C8))
    }
    private static func storm(_ n: Bool) -> SeaParams {
        SeaParams(amp: 16, speed: 2, sun: 0, cloud: 1, rain: 1, dark: 0.85, roll: 15, effort: 1, panic: 1, light: 1,
                  skyTop: rgb(n ? 0x0A141C : 0x1C2833), skyBottom: rgb(n ? 0x2A3A46 : 0x4B5D69))
    }

    private static func mix(_ a: SeaParams, _ b: SeaParams, _ t: Double) -> SeaParams {
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return SeaParams(amp: m(a.amp, b.amp), speed: m(a.speed, b.speed), sun: m(a.sun, b.sun),
                         cloud: m(a.cloud, b.cloud), rain: m(a.rain, b.rain), dark: m(a.dark, b.dark),
                         roll: m(a.roll, b.roll), effort: m(a.effort, b.effort), panic: m(a.panic, b.panic),
                         light: m(a.light, b.light),
                         skyTop: SeaScene.blend(a.skyTop, b.skyTop, t), skyBottom: SeaScene.blend(a.skyBottom, b.skyBottom, t))
    }

    private static func rgb(_ h: UInt32) -> [Double] {
        [Double((h >> 16) & 0xFF), Double((h >> 8) & 0xFF), Double(h & 0xFF)]
    }
}

enum SeaScene {
    // Escena en coordenadas lógicas de 480 de ancho; se recorta la franja visible
    static let width = 480.0, height = 300.0, top = 30.0

    private static let base: [Double] = [182, 202, 216]
    private static let ampK: [Double] = [0.5, 1, 1.25]

    static func blend(_ a: [Double], _ b: [Double], _ t: Double) -> [Double] {
        zip(a, b).map { $0 + ($1 - $0) * t }
    }

    private static func color(_ c: [Double], _ alpha: Double = 1) -> Color {
        Color(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: alpha)
    }

    private static func hash(_ n: Double) -> Double {
        let s = sin(n * 12.9898) * 43758.5453
        return s - floor(s)
    }

    private static func waveY(_ layer: Int, _ x: Double, _ t: Double, _ p: SeaParams) -> Double {
        let sp = p.speed, amp = p.amp * ampK[layer], l = Double(layer)
        return base[layer] + amp * (sin(x * 0.012 + t * sp * 0.9 + l * 1.7)
                                    + 0.5 * sin(x * 0.027 - t * sp * 1.3 + l * 0.9)
                                    + 0.25 * sin(x * 0.05 + t * sp * 1.9 + l * 2.3))
    }

    // Arco como polilínea; los ángulos van en el sentido de la pantalla (y hacia abajo)
    private static func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double) -> Path {
        Path { path in
            let steps = 14
            for i in 0...steps {
                let a = a0 + (a1 - a0) * Double(i) / Double(steps)
                let pt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
        }
    }

    private static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static let line = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

    static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, params p: SeaParams, night: Bool) {
        let s = size.width / width
        ctx.translateBy(x: 0, y: -top * s)
        ctx.scaleBy(x: s, y: s)

        let d = min(1, p.dark + (night ? 0.45 : 0))

        // Cielo plano
        ctx.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)),
                 with: .color(color(blend(p.skyTop, p.skyBottom, 0.35))))

        // Sol, o luna de noche
        if p.sun > 0.02 {
            let c = night ? color([228, 241, 238], p.sun * 0.9) : color([247, 190, 90], p.sun)
            ctx.fill(circle(392, 70, night ? 20 : 24), with: .color(c))
        }

        // Nubes
        let cloud = blend([255, 255, 255], [78, 92, 104], d)
        for (i, c) in [(60.0, 52.0, 1.0), (300.0, 88.0, 0.8)].enumerated() {
            let x = ((c.0 + t * (4 + Double(i) * 2) * (1 + p.speed * 0.4)).truncatingRemainder(dividingBy: width + 200)) - 100
            let col = color(cloud, 0.8 * p.cloud * (night ? 0.55 : 1))
            ctx.fill(Path(roundedRect: CGRect(x: x - 36 * c.2, y: c.1 - 8 * c.2, width: 72 * c.2, height: 16 * c.2),
                          cornerRadius: 8 * c.2), with: .color(col))
            ctx.fill(Path(roundedRect: CGRect(x: x - 18 * c.2, y: c.1 - 18 * c.2, width: 38 * c.2, height: 16 * c.2),
                          cornerRadius: 8 * c.2), with: .color(col))
        }

        // Rayo
        let flashSeed = floor(t / 4.3), flashPhase = t.truncatingRemainder(dividingBy: 4.3)
        if p.light > 0.5, flashPhase < 0.2 {
            var x = 90 + hash(flashSeed) * 300, y = 40.0
            var bolt = Path()
            bolt.move(to: CGPoint(x: x, y: y))
            for i in 0..<7 {
                x += (hash(flashSeed * 7 + Double(i)) - 0.5) * 30
                y += 20
                bolt.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(bolt, with: .color(.white.opacity(1 - flashPhase / 0.2)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }

        // Agua en capas planas
        let water = [blend([168, 216, 214], [59, 107, 125], d),
                     blend([112, 171, 175], [31, 78, 99], d),
                     blend([74, 150, 160], [16, 57, 74], d)]
        func layer(_ l: Int, _ alpha: Double) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: height))
            var x = 0.0
            while x <= width {
                path.addLine(to: CGPoint(x: x, y: waveY(l, x, t, p)))
                x += 6
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
            ctx.fill(path, with: .color(color(water[l], alpha)))
        }
        layer(0, 1)
        layer(1, 1)

        // Barquito
        let bx = 205.0
        let ya = waveY(1, bx - 30, t, p), yb = waveY(1, bx + 30, t, p)
        let by = (ya + yb) / 2 + 5
        let ang = atan2(yb - ya, 60) * 0.9
            + p.roll * .pi / 180 * sin(t * p.speed * 1.1)
            + p.panic * 0.04 * sin(t * 9)
        func tw(_ lx: Double, _ ly: Double) -> CGPoint {
            CGPoint(x: bx + lx * cos(ang) - ly * sin(ang), y: by + lx * sin(ang) + ly * cos(ang))
        }
        let flutter = (0.5 + p.effort * 2 + p.panic * 3) * sin(t * (4 + p.speed * 2))
        let shake = p.panic > 0.45 ? sin(t * 32) * 1.3 * p.panic : 0
        let cx = -26 + shake, cy = -28.0
        let droop = p.effort * 9 + p.panic * 5 * sin(t * 8)
        let ink = Color(.sRGB, red: 31 / 255, green: 78 / 255, blue: 99 / 255)
        let wood = Color(.sRGB, red: 90 / 255, green: 70 / 255, blue: 54 / 255)

        var boat = ctx
        boat.translateBy(x: bx, y: by)
        boat.rotate(by: .radians(ang))

        // Mástil y vela
        var mast = Path()
        mast.move(to: CGPoint(x: 8, y: -16)); mast.addLine(to: CGPoint(x: 8, y: -66))
        boat.stroke(mast, with: .color(wood), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        var sail = Path()
        sail.move(to: CGPoint(x: 10, y: -64))
        sail.addQuadCurve(to: CGPoint(x: 36 + flutter * 0.6, y: -26), control: CGPoint(x: 26 + flutter, y: -46))
        sail.addLine(to: CGPoint(x: 10, y: -26))
        sail.closeSubpath()
        boat.fill(sail, with: .color(Color(.sRGB, red: 247 / 255, green: 235 / 255, blue: 210 / 255)))

        // Casco
        var hull = Path()
        hull.move(to: CGPoint(x: -52, y: -16))
        hull.addQuadCurve(to: CGPoint(x: -20, y: 10), control: CGPoint(x: -46, y: 8))
        hull.addLine(to: CGPoint(x: 28, y: 10))
        hull.addQuadCurve(to: CGPoint(x: 60, y: -18), control: CGPoint(x: 52, y: 6))
        hull.closeSubpath()
        boat.fill(hull, with: .color(Color(.sRGB, red: 242 / 255, green: 178 / 255, blue: 92 / 255)))

        // Bichito
        boat.fill(Path(ellipseIn: CGRect(x: cx - 12, y: cy - 11, width: 24, height: 22)),
                  with: .color(Color(.sRGB, red: 124 / 255, green: 201 / 255, blue: 182 / 255)))
        if p.panic > 0.45 {
            for x in [-5.0, 5.0] {
                boat.fill(circle(cx + x, cy - 2, 3.6), with: .color(.white))
                boat.fill(circle(cx + x + sin(t * 20 + x) * 0.8, cy - 2, 1.4), with: .color(ink))
            }
            boat.fill(Path(ellipseIn: CGRect(x: cx - 2.4, y: cy + 2.8, width: 4.8, height: 6.4)), with: .color(ink))
        } else if p.effort > 0.4 {
            for x in [-5.0, 5.0] { boat.fill(circle(cx + x, cy - 2, 1.6), with: .color(ink)) }
            var brows = Path()
            brows.move(to: CGPoint(x: cx - 9, y: cy - 8)); brows.addLine(to: CGPoint(x: cx - 3, y: cy - 5.5))
            brows.move(to: CGPoint(x: cx + 9, y: cy - 8)); brows.addLine(to: CGPoint(x: cx + 3, y: cy - 5.5))
            brows.move(to: CGPoint(x: cx - 3.5, y: cy + 5)); brows.addLine(to: CGPoint(x: cx + 3.5, y: cy + 5))
            boat.stroke(brows, with: .color(ink), style: line)
        } else {
            for x in [-5.0, 5.0] { boat.stroke(arc(cx + x, cy - 1, 2.6, .pi, 2 * .pi), with: .color(ink), style: line) }
            boat.stroke(arc(cx, cy + 3, 4, 0.15 * .pi, 0.85 * .pi), with: .color(ink), style: line)
        }
        if p.effort > 0.4 {
            let k = (t * (p.panic > 0.45 ? 1.6 : 0.9)).truncatingRemainder(dividingBy: 1)
            boat.fill(Path(ellipseIn: CGRect(x: cx + 11.2, y: cy - 8 + k * 14 - 2.8, width: 3.6, height: 5.6)),
                      with: .color(Color(.sRGB, red: 150 / 255, green: 210 / 255, blue: 240 / 255, opacity: 1 - k)))
        }

        // Caña
        var rod = Path()
        rod.move(to: CGPoint(x: cx + 11, y: cy + 3))
        rod.addQuadCurve(to: CGPoint(x: cx + 66, y: -46 + droop), control: CGPoint(x: cx + 40, y: -52))
        boat.stroke(rod, with: .color(wood), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        // Sedal y flotador, en coordenadas del mundo
        let tip = tw(cx + 66, -46 + droop)
        let bobX = tip.x + 34 + p.effort * 4
        var dip = 0.0
        if p.panic > 0.45 { dip = 3 * sin(t * 7) }
        else if p.effort > 0.4 { dip = pow(max(0, sin(t * 2.2)), 6) * 5 }
        let bobY = waveY(2, bobX, t, p) - 2 + dip
        let sag = 7 - p.effort * 5 + p.panic * 7 * sin(t * 10)
        var thread = Path()
        thread.move(to: tip)
        thread.addQuadCurve(to: CGPoint(x: bobX, y: bobY),
                            control: CGPoint(x: tip.x + (bobX - tip.x) * 0.45, y: (tip.y + bobY) / 2 + sag))
        ctx.stroke(thread, with: .color(color(blend([255, 255, 255], [190, 205, 210], d), 0.8)),
                   style: StrokeStyle(lineWidth: 1, lineCap: .round))
        ctx.fill(circle(bobX, bobY, 3.2), with: .color(Color(.sRGB, red: 210 / 255, green: 96 / 255, blue: 75 / 255)))

        // Pez que salta, solo con calma
        let ph = t.truncatingRemainder(dividingBy: 9)
        if p.sun > 0.7, ph < 1 {
            let fx = 360 + ph * 60, fy = waveY(1, fx, t, p) - sin(ph * .pi) * 34
            var fish = ctx
            fish.translateBy(x: fx, y: fy)
            fish.rotate(by: .radians(atan2(-cos(ph * .pi) * 34 * .pi, 60)))
            let gold = Color(.sRGB, red: 242 / 255, green: 178 / 255, blue: 92 / 255)
            fish.fill(Path(ellipseIn: CGRect(x: -8, y: -3.6, width: 16, height: 7.2)), with: .color(gold))
            var tail = Path()
            tail.move(to: CGPoint(x: -7, y: 0)); tail.addLine(to: CGPoint(x: -13, y: -4)); tail.addLine(to: CGPoint(x: -13, y: 4))
            tail.closeSubpath()
            fish.fill(tail, with: .color(gold))
        }

        layer(2, 0.92)

        // Lluvia
        if p.rain > 0.02 {
            var rain = Path()
            for i in 0..<Int((50 * p.rain).rounded()) {
                let fi = Double(i)
                let x = (fi * 53.7 + t * 90).truncatingRemainder(dividingBy: width + 60) - 30
                let y = (fi * 97.3 + t * 480).truncatingRemainder(dividingBy: height)
                rain.move(to: CGPoint(x: x, y: y)); rain.addLine(to: CGPoint(x: x - 4, y: y + 13))
            }
            ctx.stroke(rain, with: .color(Color(.sRGB, red: 220 / 255, green: 236 / 255, blue: 242 / 255, opacity: 0.5 * p.rain)),
                       style: StrokeStyle(lineWidth: 1))
        }

        // Destello del rayo
        if p.light > 0.5, flashPhase < 0.18 {
            ctx.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)),
                     with: .color(.white.opacity(0.3 * (1 - flashPhase / 0.18))))
        }
    }
}
