import Foundation

// Lógica pura del semáforo: de runs de GitHub a estado del entorno
enum StatusCalculator {
    static func status(
        runsByRepo: [(repo: String, runs: [WorkflowRun])],
        workflowFilter: String,
        failureWindow: TimeInterval,
        now: Date = Date()
    ) -> EnvStatus {
        var st = EnvStatus()
        let filter = workflowFilter.trimmingCharacters(in: .whitespaces)

        for (repo, all) in runsByRepo {
            let runs = filter.isEmpty ? all : all.filter { ($0.name ?? "").localizedCaseInsensitiveContains(filter) }

            for r in runs where r.isActive {
                st.active.append(ActiveRun(
                    id: r.id,
                    repo: repo,
                    workflow: r.name ?? "",
                    actor: r.actor?.login ?? "",
                    startedAt: r.isRunning ? r.run_started_at : nil,
                    queued: !r.isRunning,
                    expectedDuration: expectedDuration(of: r, in: runs),
                    url: r.html_url
                ))
            }

            let finished = runs.filter(\.isDeployOutcome)
            if let last = finished.max(by: { $0.updated_at < $1.updated_at }) {
                let f = finishedRun(last, repo: repo)
                if st.lastDeploy.map({ f.finishedAt > $0.finishedAt }) ?? true { st.lastDeploy = f }
            }

            // Fallo = la última ejecución de algún workflow terminó mal hace poco
            let latestPerWorkflow = Dictionary(grouping: finished, by: \.workflow_id)
                .compactMap { $0.value.max(by: { $0.updated_at < $1.updated_at }) }
            for r in latestPerWorkflow where r.conclusion != "success" && now.timeIntervalSince(r.updated_at) < failureWindow {
                let f = finishedRun(r, repo: repo)
                if st.failure.map({ f.finishedAt > $0.finishedAt }) ?? true { st.failure = f }
            }
        }

        st.active.sort { ($0.startedAt ?? .distantFuture) < ($1.startedAt ?? .distantFuture) }
        if !st.active.isEmpty {
            st.state = st.active.allSatisfy(\.queued) ? .queued : .busy
        } else {
            st.state = st.failure != nil ? .failed : .free
        }
        return st
    }

    // Mediana de las ejecuciones correctas del mismo workflow
    static func expectedDuration(of run: WorkflowRun, in runs: [WorkflowRun]) -> TimeInterval? {
        let past = runs
            .filter { $0.workflow_id == run.workflow_id && $0.conclusion == "success" }
            .compactMap(\.duration)
            .sorted()
        return past.isEmpty ? nil : past[past.count / 2]
    }

    private static func finishedRun(_ r: WorkflowRun, repo: String) -> FinishedRun {
        FinishedRun(repo: repo, workflow: r.name ?? "", finishedAt: r.updated_at,
                    success: r.conclusion == "success", url: r.html_url)
    }
}
