import Foundation

// Un entorno = una rama, con un filtro opcional por nombre de workflow
struct EnvConfig: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var branch: String
    var workflowFilter: String = ""
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var owner: String
    var repos: [String] = []
    var environments: [EnvConfig] = Profile.defaultEnvironments

    static let defaultEnvironments = [
        EnvConfig(name: "DEV", branch: "develop"),
        EnvConfig(name: "PRO", branch: "main"),
    ]

    static let maxEnvironments = 5

    // Lo que afecta a la consulta; renombrar el perfil no la relanza
    var pollingKey: PollingKey { PollingKey(owner: owner, repos: repos, environments: environments) }

    struct PollingKey: Equatable {
        let owner: String
        let repos: [String]
        let environments: [EnvConfig]
    }
}
