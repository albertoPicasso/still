import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: StatusViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    var body: some View {
        let theme = Theme.of(scheme)
        VStack(alignment: .leading, spacing: 0) {
            SeaView(mood: viewModel.seaMood, night: scheme == .dark)
                .frame(height: 144)

            Group {
                switch viewModel.hint {
                case .noProfile:
                    HintView(text: "Crea un perfil para empezar", theme: theme, action: openSettings)
                case .noRepos:
                    HintView(text: "Elige qué repos vigilar", theme: theme, action: openSettings)
                case nil:
                    ForEach(viewModel.environments) { env in
                        EnvSectionView(presentation: EnvPresentation(env: env, status: viewModel.status(for: env)),
                                       theme: theme)
                    }
                }
            }
            .padding(.top, -6)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.still(11))
                    .foregroundStyle(theme.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle().fill(theme.line).frame(height: 0.5).padding(.horizontal, 24).padding(.top, 8)

            OptionsMenu(viewModel: viewModel, theme: theme, openSettings: openSettings)
                .padding(.vertical, 6)
        }
        .frame(width: 330)
        .background(theme.background)
        .foregroundStyle(theme.text)
        .background {
            // Atajos de teclado siempre activos, aunque el menú de opciones esté cerrado
            Group {
                Button("", action: viewModel.refreshNow).keyboardShortcut("r")
                Button("", action: openSettings).keyboardShortcut(",")
                Button("") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .opacity(0)
            .allowsHitTesting(false)
            .frame(width: 0, height: 0)
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: SettingsView.windowID)
    }
}

// Opciones agrupadas: se despliegan al pasar el cursor por encima
private struct OptionsMenu: View {
    @Bindable var viewModel: StatusViewModel
    let theme: Theme
    let openSettings: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button { setOpen(true) } label: {
                HStack {
                    Text("Opciones")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .font(.still(13, .medium))
                .foregroundStyle(open ? theme.text : theme.text2)
                .padding(.horizontal, 24)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 0) {
                    if viewModel.profiles.count > 1 {
                        ProfileMenu(viewModel: viewModel, theme: theme)
                    }
                    if let url = viewModel.ownerURL {
                        MenuRow(title: "Abrir en GitHub", trailing: "→", theme: theme) { openURL(url) }
                    }
                    MenuRow(title: "Actualizar", trailing: "⌘R", theme: theme, action: viewModel.refreshNow)
                    MenuRow(title: "Ajustes", trailing: "⌘,", theme: theme, action: openSettings)
                    MenuRow(title: "Salir", trailing: "⌘Q", theme: theme) { NSApp.terminate(nil) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onHover { setOpen($0) }
    }

    private func setOpen(_ value: Bool) {
        withAnimation(.easeOut(duration: 0.18)) { open = value }
    }
}

private struct HintView: View {
    let text: String
    let theme: Theme
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(theme.text3).frame(width: 8, height: 8)
            Text(text).font(.still(15, .semibold))
            Spacer()
            Button("Configurar →", action: action)
                .buttonStyle(.plain)
                .font(.still(12))
                .foregroundStyle(theme.text2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct ProfileMenu: View {
    @Bindable var viewModel: StatusViewModel
    let theme: Theme

    var body: some View {
        Menu {
            Picker("Perfil", selection: $viewModel.activeProfileID) {
                ForEach(viewModel.profiles) { Text($0.name).tag(Optional($0.id)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack {
                Text("Perfil")
                Spacer()
                Text(viewModel.activeProfileName).foregroundStyle(theme.text3)
            }
            .font(.still(13))
            .foregroundStyle(theme.text2)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
    }
}

struct MenuRow: View {
    let title: String
    let trailing: String
    let theme: Theme
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(trailing).foregroundStyle(theme.text3)
            }
            .font(.still(13, .medium))
            .foregroundStyle(hover ? theme.text : theme.text2)
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
