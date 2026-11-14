import SwiftUI
import AppKit

// Paleta de agua: calma en claro, océano profundo en oscuro
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
    let logo: Color

    static func of(_ scheme: ColorScheme) -> Theme { scheme == .dark ? dark : light }

    static let light = Theme(
        background: Color(hex: 0xF0F7F4),
        text: Color(hex: 0x1F4E63),
        text2: Color(hex: 0x1F4E63).opacity(0.70),
        text3: Color(hex: 0x1F4E63).opacity(0.46),
        line: Color(hex: 0x1F4E63).opacity(0.10),
        apricot: Color(hex: 0xF0A23A),
        apricotText: Color(hex: 0xB06A12),
        sage: Color(hex: 0x4FA595),
        red: Color(hex: 0xD2604B),
        logo: Color(hex: 0x1F4E63)
    )

    static let dark = Theme(
        background: Color(hex: 0x0B1B24),
        text: Color(hex: 0xE4F1EE),
        text2: Color(hex: 0xE4F1EE).opacity(0.64),
        text3: Color(hex: 0xE4F1EE).opacity(0.40),
        line: Color(hex: 0xE4F1EE).opacity(0.09),
        apricot: Color(hex: 0xF2B25C),
        apricotText: Color(hex: 0xF2B25C),
        sage: Color(hex: 0x7CC9B6),
        red: Color(hex: 0xE5806B),
        logo: Color(hex: 0x7CC9B6)
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

extension Font {
    // DM Sans para el texto y Bagel Fat One solo para el logo
    static func still(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("DM Sans", size: size).weight(weight)
    }
    static func logo(_ size: CGFloat) -> Font { .custom("Bagel Fat One", size: size) }
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
        case .free: NSColor(srgbRed: 0.31, green: 0.65, blue: 0.58, alpha: 1)
        case .busy, .queued: NSColor(srgbRed: 0.95, green: 0.64, blue: 0.25, alpha: 1)
        case .failed: NSColor(srgbRed: 0.88, green: 0.45, blue: 0.33, alpha: 1)
        case .unknown: .secondaryLabelColor
        }
    }
}
