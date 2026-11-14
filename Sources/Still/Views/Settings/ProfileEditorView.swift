import SwiftUI

struct ProfileEditorView: View {
    @Bindable var viewModel: ProfileEditorViewModel
    let owners: [String]

    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $viewModel.name)
                Picker("Cuenta u organización", selection: $viewModel.owner) {
                    ForEach(viewModel.ownerOptions(from: owners), id: \.self) { Text($0).tag($0) }
                }
                if !viewModel.isActive {
                    Button("Usar este perfil", action: viewModel.activate)
                }
            }

            environmentsSection
            reposSection
        }
        .formStyle(.grouped)
        .task(id: viewModel.owner) { await viewModel.loadRepos() }
    }

    private var environmentsSection: some View {
        Section {
            ForEach($viewModel.environments) { $env in
                HStack(spacing: 8) {
                    TextField("Nombre", text: $env.name).frame(width: 70)
                    TextField("Rama", text: $env.branch)
                    TextField("Workflow contiene", text: $env.workflowFilter, prompt: Text("cualquiera"))
                    Button { viewModel.removeEnvironment(env.id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .help("Quitar entorno")
                }
                .labelsHidden()
            }
            Button("Añadir entorno", action: viewModel.addEnvironment)
                .disabled(!viewModel.canAddEnvironment)
        } header: {
            Text("Entornos")
        } footer: {
            Text("Cada entorno es una rama. El filtro por nombre de workflow es opcional, por ejemplo «PRODUCTION».")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var reposSection: some View {
        Section {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = viewModel.loadError {
                Text(error).foregroundStyle(.red)
            } else {
                HStack {
                    TextField("Buscar", text: $viewModel.search)
                    Button("Todos", action: viewModel.watchAllFiltered)
                    Button("Ninguno", action: viewModel.watchNoneFiltered)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.filteredRepos) { repo in
                            Toggle(isOn: Binding(get: { viewModel.isWatched(repo.name) },
                                                 set: { viewModel.setWatched(repo.name, $0) })) {
                                HStack {
                                    Text(repo.name)
                                    Spacer()
                                    if let pushed = repo.pushed_at {
                                        Text(Formatters.relative(pushed)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200)
            }
        } header: {
            Text("Repos vigilados · \(viewModel.watchedCount) de \(viewModel.repos.count)")
        }
    }
}
