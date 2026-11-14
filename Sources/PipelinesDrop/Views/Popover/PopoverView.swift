import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: StatusViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    var body: some View {
        let theme = Theme.of(scheme)
        VStack(alignment: .leading, spacing: 0) {
            WavesView(color: theme.waves, boost: theme.wavesBoost)
                .frame(height: 72)

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
            .padding(.top, -14)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle().fill(theme.line).frame(height: 0.5).padding(.horizontal, 24).padding(.top, 8)

            VStack(spacing: 0) {
                if viewModel.profiles.count > 1 {
                    ProfileMenu(viewModel: viewModel, theme: theme)
                }
                if let url = viewModel.ownerURL {
                    MenuRow(title: "Abrir en GitHub", trailing: "→", theme: theme) { openURL(url) }
                }
                MenuRow(title: "Actualizar", trailing: "⌘R", theme: theme, action: viewModel.refreshNow)
                    .keyboardShortcut("r")
                MenuRow(title: "Ajustes", trailing: "⌘,", theme: theme, action: openSettings)
                    .keyboardShortcut(",")
                MenuRow(title: "Salir", trailing: "⌘Q", theme: theme) { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.vertical, 8)
        }
        .frame(width: 330)
        .background(theme.background)
        .foregroundStyle(theme.text)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: SettingsView.windowID)
    }
}

private struct HintView: View {
    let text: String
    let theme: Theme
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(theme.text3).frame(width: 8, height: 8)
            Text(text).font(.system(size: 15, design: .rounded))
            Spacer()
            Button("Configurar →", action: action)
                .buttonStyle(.plain)
                .font(.system(size: 12))
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
            .font(.system(size: 12))
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
            .font(.system(size: 12))
            .foregroundStyle(hover ? theme.text : theme.text2)
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
