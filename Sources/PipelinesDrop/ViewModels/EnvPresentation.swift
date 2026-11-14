import Foundation

// Textos que muestra cada entorno, separados de la vista para poder probarlos
struct EnvPresentation: Equatable {
    enum Tone: Equatable { case normal, busy, failed }

    let label: String
    let state: EnvState
    let title: String
    let subtitle: String?
    let tone: Tone
    let logURL: URL?
    let runs: [ActiveRun]

    init(env: EnvConfig, status: EnvStatus, now: Date = Date()) {
        label = env.name.uppercased()
        state = status.state
        runs = status.active
        logURL = status.state == .failed ? status.failure?.url : nil

        switch status.state {
        case .free:
            title = "Libre"
            subtitle = status.lastDeploy.map { "Último deploy \(Formatters.relative($0.finishedAt, to: now))" } ?? "Todo en calma"
            tone = .normal
        case .busy:
            title = "Desplegando"
            subtitle = nil
            tone = .busy
        case .queued:
            title = "En cola"
            subtitle = nil
            tone = .busy
        case .failed:
            title = "Algo falló"
            subtitle = status.failure.map { "\($0.repo) · \(Formatters.relative($0.finishedAt, to: now))" }
            tone = .failed
        case .unknown:
            title = "…"
            subtitle = nil
            tone = .normal
        }
    }
}

struct RunProgress: Equatable {
    let elapsed: String?
    let remaining: String?
    let fraction: Double

    init(run: ActiveRun, now: Date) {
        guard !run.queued else {
            elapsed = nil
            remaining = nil
            fraction = 0
            return
        }
        let seconds = run.startedAt.map { now.timeIntervalSince($0) } ?? 0
        elapsed = Formatters.clock(seconds)
        if let exp = run.expectedDuration, exp > 0 {
            let left = Int((exp - seconds) / 60)
            remaining = left > 0 ? "\(left) min" : "ya casi"
            fraction = min(1, seconds / exp)
        } else {
            remaining = nil
            fraction = 0.5
        }
    }
}
