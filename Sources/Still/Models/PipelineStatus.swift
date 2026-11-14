import Foundation

enum EnvState: Equatable, Sendable {
    case free, busy, queued, failed, unknown
}

extension Array where Element == EnvState {
    // Estado del mar: 0 calma, 0.5 desplegando, 1 temporal
    var seaMood: Double {
        if contains(.failed) { return 1 }
        if contains(where: { $0 == .busy || $0 == .queued }) { return 0.5 }
        return 0
    }
}

struct ActiveRun: Identifiable, Equatable, Sendable {
    let id: Int
    let repo: String
    let workflow: String
    let actor: String
    let startedAt: Date?
    let queued: Bool
    let expectedDuration: TimeInterval?
    let url: URL
}

struct FinishedRun: Equatable, Sendable {
    let repo: String
    let workflow: String
    let finishedAt: Date
    let success: Bool
    let url: URL
}

struct EnvStatus: Equatable, Sendable {
    var state: EnvState = .unknown
    var active: [ActiveRun] = []
    var lastDeploy: FinishedRun?
    var failure: FinishedRun?
}
