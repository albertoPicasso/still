import SwiftUI

// Icono de la app: "still." en el color más claro sobre el más oscuro, con la forma de icono de macOS
struct AppIconView: View {
    let side: CGFloat

    private var body_: CGFloat { side * 824 / 1024 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: body_ * 0.2237, style: .continuous)
                .fill(Color(hex: 0x0B1B24))
                .frame(width: body_, height: body_)
                .shadow(color: .black.opacity(0.28), radius: side * 14 / 1024, y: side * 10 / 1024)
            Text("still.")
                .font(.logo(body_ * 0.34))
                .foregroundStyle(Color(hex: 0xF0F7F4))
                .offset(y: -body_ * 0.02)
        }
        .frame(width: side, height: side)
    }
}
