import Foundation

// Subconjunto de las respuestas de la API de GitHub que usamos

struct RunsResponse: Decodable {
    let workflow_runs: [WorkflowRun]
}

struct WorkflowRun: Decodable, Sendable {
    let id: Int
    let name: String?
    let workflow_id: Int
    let head_branch: String?
    let status: String
    let conclusion: String?
    let run_started_at: Date?
    let updated_at: Date
    let html_url: URL
    let actor: Actor?

    struct Actor: Decodable, Sendable { let login: String }

    var isActive: Bool {
        ["in_progress", "queued", "waiting", "pending", "requested"].contains(status)
    }

    var isRunning: Bool { status == "in_progress" }

    // Cancelados y saltados no cuentan como deploy
    var isDeployOutcome: Bool {
        conclusion == "success" || conclusion == "failure" || conclusion == "timed_out"
    }

    var duration: TimeInterval? {
        guard status == "completed", let start = run_started_at else { return nil }
        return updated_at.timeIntervalSince(start)
    }
}

struct Repo: Decodable, Identifiable, Sendable {
    let name: String
    let archived: Bool
    let pushed_at: Date?
    var id: String { name }
}

struct Account: Decodable, Sendable {
    let login: String
}
