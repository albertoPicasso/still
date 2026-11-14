import Foundation

// Copia una sola vez los perfiles y ajustes de la app con su nombre anterior
enum LegacyDefaults {
    private static let oldDomain = "dev.pipelinesdrop.app"
    private static let marker = "migratedFromPipelinesDrop"

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: marker) else { return }
        defaults.set(true, forKey: marker)
        guard let old = defaults.persistentDomain(forName: oldDomain) else { return }
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }
}
