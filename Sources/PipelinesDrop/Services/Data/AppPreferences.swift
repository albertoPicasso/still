import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
final class AppPreferences {
    @ObservationIgnored private let defaults: UserDefaults

    var pollInterval: TimeInterval {
        didSet { defaults.set(pollInterval, forKey: Keys.interval) }
    }

    var failureHours: Double {
        didSet { defaults.set(failureHours, forKey: Keys.failureHours) }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                try launchAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    var failureWindow: TimeInterval { failureHours * 3600 }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Keys.interval: 30.0, Keys.failureHours: 12.0])
        pollInterval = max(10, defaults.double(forKey: Keys.interval))
        failureHours = defaults.double(forKey: Keys.failureHours)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private enum Keys {
        static let interval = "pollInterval"
        static let failureHours = "failureHours"
    }
}
