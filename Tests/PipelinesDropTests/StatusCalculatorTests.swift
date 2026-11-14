import Foundation
import Testing
@testable import PipelinesDrop

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 3600

private func run(
    _ id: Int,
    workflow: Int = 1,
    name: String = "Deploy",
    status: String = "completed",
    conclusion: String? = "success",
    started: TimeInterval = -2 * hour,
    duration: TimeInterval = 300
) -> WorkflowRun {
    let start = now.addingTimeInterval(started)
    return WorkflowRun(
        id: id, name: name, workflow_id: workflow, head_branch: "main",
        status: status, conclusion: conclusion,
        run_started_at: start, updated_at: start.addingTimeInterval(duration),
        html_url: URL(string: "https://github.com/acme/api/actions/runs/\(id)")!,
        actor: .init(login: "dev"))
}

private func status(_ runs: [WorkflowRun], repo: String = "api", filter: String = "") -> EnvStatus {
    StatusCalculator.status(runsByRepo: [(repo, runs)], workflowFilter: filter, failureWindow: 12 * hour, now: now)
}

@Suite("Cálculo del semáforo")
struct StatusCalculatorTests {
    @Test func sinRunsEstaLibre() {
        let s = status([])
        #expect(s.state == .free)
        #expect(s.lastDeploy == nil)
    }

    @Test func runEnCursoMarcaOcupadoConDuracionEsperada() {
        let s = status([
            run(1, status: "in_progress", conclusion: nil, started: -60),
            run(2, duration: 200),
            run(3, duration: 300),
            run(4, duration: 400),
            run(5, workflow: 2, duration: 9999),
        ])
        #expect(s.state == .busy)
        #expect(s.active.count == 1)
        #expect(s.active[0].expectedDuration == 300)
        #expect(s.active[0].queued == false)
    }

    @Test func soloEnColaMarcaEnCola() {
        let s = status([run(1, status: "queued", conclusion: nil)])
        #expect(s.state == .queued)
        #expect(s.active[0].startedAt == nil)
    }

    @Test func falloRecienteMarcaRojo() {
        let s = status([run(1, conclusion: "failure", started: -hour)])
        #expect(s.state == .failed)
        #expect(s.failure?.repo == "api")
    }

    @Test func falloArregladoDespuesQuedaLibre() {
        let s = status([
            run(1, conclusion: "failure", started: -2 * hour),
            run(2, conclusion: "success", started: -hour),
        ])
        #expect(s.state == .free)
        #expect(s.failure == nil)
        #expect(s.lastDeploy?.success == true)
    }

    @Test func falloAntiguoNoCuenta() {
        let s = status([run(1, conclusion: "failure", started: -24 * hour)])
        #expect(s.state == .free)
    }

    @Test func cancelacionesNoCuentanComoDeploy() {
        let s = status([run(1, conclusion: "cancelled", started: -hour)])
        #expect(s.lastDeploy == nil)
        #expect(s.state == .free)
    }

    @Test func filtroPorNombreDeWorkflow() {
        let s = status([
            run(1, name: "Tests", status: "in_progress", conclusion: nil),
            run(2, name: "Deploy to PRODUCTION", conclusion: "success"),
        ], filter: "production")
        #expect(s.state == .free)
        #expect(s.lastDeploy?.workflow == "Deploy to PRODUCTION")
    }

    @Test func ultimoDeployEntreVariosRepos() {
        let s = StatusCalculator.status(
            runsByRepo: [("api", [run(1, started: -3 * hour)]), ("web", [run(2, started: -hour)])],
            workflowFilter: "", failureWindow: 12 * hour, now: now)
        #expect(s.lastDeploy?.repo == "web")
    }
}

@Suite("Presentación")
struct PresentationTests {
    private let env = EnvConfig(name: "pro", branch: "main")

    @Test func titulosPorEstado() {
        #expect(EnvPresentation(env: env, status: EnvStatus(state: .free)).title == "Libre")
        #expect(EnvPresentation(env: env, status: EnvStatus(state: .busy)).tone == .busy)
        #expect(EnvPresentation(env: env, status: EnvStatus(state: .free)).label == "PRO")
    }

    @Test func soloHayLogCuandoFalla() {
        let failure = FinishedRun(repo: "api", workflow: "Deploy", finishedAt: now, success: false,
                                  url: URL(string: "https://github.com")!)
        #expect(EnvPresentation(env: env, status: EnvStatus(state: .failed, failure: failure)).logURL != nil)
        #expect(EnvPresentation(env: env, status: EnvStatus(state: .free, failure: failure)).logURL == nil)
    }

    @Test func progresoYTiempoRestante() {
        let r = ActiveRun(id: 1, repo: "api", workflow: "", actor: "", startedAt: now.addingTimeInterval(-150),
                          queued: false, expectedDuration: 300, url: URL(string: "https://github.com")!)
        let p = RunProgress(run: r, now: now)
        #expect(p.elapsed == "2:30")
        #expect(p.remaining == "2 min")
        #expect(p.fraction == 0.5)
    }
}

@Suite("Perfiles")
@MainActor
struct ProfileStoreTests {
    @Test func elPrimerPerfilQuedaActivoYAlBorrarloPasaAlSiguiente() {
        let store = ProfileStore(persistence: InMemoryProfilePersistence())
        let a = store.add(owner: "acme")
        let b = store.add(owner: "me")
        #expect(store.activeID == a.id)
        store.remove(a.id)
        #expect(store.activeID == b.id)
    }

    @Test func renombrarNoCambiaLaClaveDeConsulta() {
        var p = Profile(name: "a", owner: "acme", repos: ["api"])
        let key = p.pollingKey
        p.name = "b"
        #expect(p.pollingKey == key)
        p.repos.append("web")
        #expect(p.pollingKey != key)
    }
}
