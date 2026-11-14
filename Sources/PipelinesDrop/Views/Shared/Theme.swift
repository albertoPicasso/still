import SwiftUI
import AppKit

// Paleta cálida (crema, albaricoque y salvia) en claro y oscuro
struct Theme {
    let background: Color
    let text: Color
    let text2: Color
    let text3: Color
    let line: Color
    let apricot: Color
    let apricotText: Color
    let sage: Color
    let red: Color
    let waves: Color
    let wavesBoost: Double

    static func of(_ scheme: ColorScheme) -> Theme { scheme == .dark ? dark : light }

    static let light = Theme(
        background: Color(hex: 0xFFFBF2),
        text: Color(hex: 0x1B1D1B),
        text2: Color(hex: 0x1B1D1B).opacity(0.66),
        text3: Color(hex: 0x1B1D1B).opacity(0.42),
        line: Color(hex: 0x1B1D1B).opacity(0.09),
        apricot: Color(hex: 0xE09A3E),
        apricotText: Color(hex: 0xB06A12),
        sage: Color(hex: 0x688D62),
        red: Color(hex: 0xC9603F),
        waves: Color(hex: 0x688D62),
        wavesBoost: 1.7
    )

    static let dark = Theme(
        background: Color(hex: 0x171917),
        text: Color(hex: 0xFFF6E1),
        text2: Color(hex: 0xFFF6E1).opacity(0.62),
        text3: Color(hex: 0xFFF6E1).opacity(0.38),
        line: Color(hex: 0xFFF6E1).opacity(0.08),
        apricot: Color(hex: 0xFAC173),
        apricotText: Color(hex: 0xFAC173),
        sage: Color(hex: 0x8FAE88),
        red: Color(hex: 0xE58B6D),
        waves: Color(hex: 0xFAC173),
        wavesBoost: 1.3
    )

    func color(for state: EnvState) -> Color {
        switch state {
        case .free: sage
        case .busy, .queued: apricot
        case .failed: red
        case .unknown: text3
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum MenuBarIcon {
    // Un punto por entorno; no es plantilla para que macOS no lo pase a monocromo
    static func image(_ states: [EnvState]) -> NSImage {
        let dots = states.isEmpty ? [EnvState.unknown] : states
        let d: CGFloat = 7, gap: CGFloat = 4
        let size = NSSize(width: 6 + CGFloat(dots.count) * d + CGFloat(dots.count - 1) * gap, height: 16)
        let img = NSImage(size: size, flipped: false) { _ in
            let y = (size.height - d) / 2
            for (i, s) in dots.enumerated() {
                color(s).setFill()
                NSBezierPath(ovalIn: NSRect(x: 3 + CGFloat(i) * (d + gap), y: y, width: d, height: d)).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func color(_ s: EnvState) -> NSColor {
        switch s {
        case .free: NSColor(srgbRed: 0.56, green: 0.68, blue: 0.53, alpha: 1)
        case .busy, .queued: NSColor(srgbRed: 0.94, green: 0.68, blue: 0.33, alpha: 1)
        case .failed: NSColor(srgbRed: 0.88, green: 0.45, blue: 0.33, alpha: 1)
        case .unknown: .secondaryLabelColor
        }
    }
}
