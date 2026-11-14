import SwiftUI

// Curvas de nivel animadas: ruido Perlin 3D + marching squares
struct WavesView: View {
    let color: Color
    let boost: Double

    @State private var field = WaveField()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate * 1000
                field.draw(in: &ctx, size: size, t: t, color: color, boost: boost)
            }
        }
        .allowsHitTesting(false)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }
}

final class WaveField {
    private let perm: [Int]
    private var values: [Double] = []

    private let cell: CGFloat = 5
    private let levels = 12

    init() {
        let p = Array(0..<256).shuffled()
        perm = p + p
    }

    func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, color: Color, boost: Double) {
        let cols = Int(ceil(size.width / cell)) + 2
        let rows = Int(ceil(size.height / cell)) + 2
        if values.count != cols * rows { values = Array(repeating: 0, count: cols * rows) }

        sampleField(cols: cols, rows: rows, t: t)

        for l in 0..<levels {
            let level = -1 + 2 * (Double(l) + 0.5) / Double(levels)
            let alpha = min(0.5, max(0.06, (0.16 + 0.09 * sin(1.3 * Double(l) + t * 1.2e-4)) * boost))
            let width = (1 + 0.1 * (1 + sin(Double(l) * .pi * 2 / Double(levels)))) * 0.8
            var path = Path()
            for j in 0..<(rows - 1) {
                for i in 0..<(cols - 1) {
                    addContour(&path, i: i, j: j, cols: cols, level: level)
                }
            }
            ctx.stroke(path, with: .color(color.opacity(alpha)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    private func sampleField(cols: Int, rows: Int, t: Double) {
        let tz = t * 4e-5
        let dx = t * 0.004
        for j in 0..<rows {
            let y = Double(j) * cell
            for i in 0..<cols {
                let x = Double(i) * cell
                values[j * cols + i] = noise((x + dx) * 0.009, y * 0.009, tz)
                    + 0.3 * noise(x * 0.021 + 11, y * 0.021 - 7, tz * 1.4)
            }
        }
    }

    // Marching squares de una celda, sin reservar memoria
    private func addContour(_ path: inout Path, i: Int, j: Int, cols: Int, level: Double) {
        let k = j * cols + i
        let v0 = values[k], v1 = values[k + 1], v2 = values[k + cols + 1], v3 = values[k + cols]
        let b0 = v0 > level, b1 = v1 > level, b2 = v2 > level, b3 = v3 > level
        if b0 == b1 && b1 == b2 && b2 == b3 { return }

        let x = CGFloat(i) * cell, y = CGFloat(j) * cell
        func lerp(_ a: Double, _ b: Double) -> CGFloat { CGFloat((level - a) / (b - a)) * cell }

        var first: CGPoint?
        func emit(_ p: CGPoint) {
            if let f = first {
                path.move(to: f)
                path.addLine(to: p)
                first = nil
            } else {
                first = p
            }
        }
        if b0 != b1 { emit(CGPoint(x: x + lerp(v0, v1), y: y)) }
        if b1 != b2 { emit(CGPoint(x: x + cell, y: y + lerp(v1, v2))) }
        if b2 != b3 { emit(CGPoint(x: x + cell - lerp(v2, v3), y: y + cell)) }
        if b3 != b0 { emit(CGPoint(x: x, y: y + cell - lerp(v3, v0))) }
    }

    private func noise(_ xIn: Double, _ yIn: Double, _ zIn: Double) -> Double {
        let X = Int(floor(xIn)) & 255, Y = Int(floor(yIn)) & 255, Z = Int(floor(zIn)) & 255
        let x = xIn - floor(xIn), y = yIn - floor(yIn), z = zIn - floor(zIn)
        let u = fade(x), v = fade(y), w = fade(z)
        let A = perm[X] + Y, AA = perm[A] + Z, AB = perm[A + 1] + Z
        let B = perm[X + 1] + Y, BA = perm[B] + Z, BB = perm[B + 1] + Z
        let r = mix(mix(mix(grad(perm[AA], x, y, z), grad(perm[BA], x - 1, y, z), u),
                        mix(grad(perm[AB], x, y - 1, z), grad(perm[BB], x - 1, y - 1, z), u), v),
                    mix(mix(grad(perm[AA + 1], x, y, z - 1), grad(perm[BA + 1], x - 1, y, z - 1), u),
                        mix(grad(perm[AB + 1], x, y - 1, z - 1), grad(perm[BB + 1], x - 1, y - 1, z - 1), u), v), w)
        return r * 1.6
    }

    private func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + t * (b - a) }
    private func grad(_ hash: Int, _ x: Double, _ y: Double, _ z: Double) -> Double {
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -v : v)
    }
}
