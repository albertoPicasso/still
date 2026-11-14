import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 190)
            Divider()
            detail.frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
        .font(.still(13))
        .frame(width: 680, height: 620)
        .task { await viewModel.onAppear() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Text("still.")
                .font(.logo(34))
                .foregroundStyle(Theme.of(scheme).logo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 4)

            List(selection: $viewModel.selection) {
                Section("Perfiles") {
                    ForEach(viewModel.profiles) { p in
                        HStack {
                            Text(p.name.isEmpty ? "Sin nombre" : p.name)
                            Spacer()
                            if viewModel.isActive(p.id) {
                                Image(systemName: "checkmark").foregroundStyle(.secondary)
                            }
                        }
                        .tag(SettingsViewModel.Selection.profile(p.id))
                    }
                }
                Section("General") {
                    Text("Preferencias").tag(SettingsViewModel.Selection.general)
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 2) {
                Button(action: viewModel.addProfile) { Image(systemName: "plus") }
                    .help("Añadir perfil")
                Button(action: viewModel.removeSelected) { Image(systemName: "minus") }
                    .help("Borrar perfil")
                    .disabled(!viewModel.canRemove)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if viewModel.selection == .general {
            PreferencesView(preferences: viewModel.preferences)
        } else if let id = viewModel.selectedProfileID {
            ProfileEditorView(viewModel: viewModel.editor(for: id), owners: viewModel.owners)
                .id(id)
        } else {
            ContentUnavailableView("Crea un perfil", systemImage: "square.stack.3d.up",
                                   description: Text("Un perfil es una cuenta u organización con sus repos y entornos."))
        }
    }
}

private struct PreferencesView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        Form {
            Section {
                Stepper("Consultar cada \(Int(preferences.pollInterval)) s",
                        value: $preferences.pollInterval, in: 10...300, step: 10)
                Stepper("Marcar fallo durante \(Int(preferences.failureHours)) h",
                        value: $preferences.failureHours, in: 1...72)
                Toggle("Abrir al iniciar sesión", isOn: $preferences.launchAtLogin)
            } footer: {
                Text("Usa la sesión de la CLI gh de este ordenador.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
