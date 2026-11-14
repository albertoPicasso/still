import Foundation

enum EnvState: Equatable, Sendable {
    case free, busy, queued, failed, unknown
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
