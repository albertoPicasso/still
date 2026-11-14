import Foundation

protocol GitHubService: Sendable {
    func owners() async throws -> [String]
    func repos(owner: String) async throws -> [Repo]
    func runs(owner: String, repo: String, branch: String) async throws -> [WorkflowRun]
    func resetSession() async
}

enum GitHubError: LocalizedError {
    case unauthorized
    case rateLimited
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: "La sesión de gh no es válida. Ejecuta `gh auth login`."
        case .rateLimited: "GitHub ha limitado las consultas. Sube el intervalo en Preferencias."
        case .http(let code, let path): "GitHub respondió \(code) en \(path)."
        case .badResponse: "Respuesta inesperada de GitHub."
        }
    }
}

actor GitHubClient: GitHubService {
    private let session: URLSession
    private let tokenProvider: @Sendable () throws -> String
    private var etags: [String: (etag: String, data: Data)] = [:]
    private var token: String?
    private var viewerLogin: String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(tokenProvider: @escaping @Sendable () throws -> String = { try GhCLI.token() }) {
        self.tokenProvider = tokenProvider
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    func resetSession() {
        token = nil
        viewerLogin = nil
    }

    // Tu usuario primero y después tus organizaciones
    func owners() async throws -> [String] {
        let me = try await viewer()
        let orgs: [Account] = try await get("/user/orgs?per_page=100")
        return [me] + orgs.map(\.login).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func repos(owner: String) async throws -> [Repo] {
        let all: [Repo]
        if owner.caseInsensitiveCompare(try await viewer()) == .orderedSame {
            all = try await getAll("/user/repos?affiliation=owner&sort=pushed")
        } else {
            do {
                all = try await getAll("/orgs/\(owner)/repos?type=all&sort=pushed")
            } catch GitHubError.http(404, _) {
                all = try await getAll("/users/\(owner)/repos?type=owner&sort=pushed")
            }
        }
        return all
            .filter { !$0.archived }
            .sorted { ($0.pushed_at ?? .distantPast) > ($1.pushed_at ?? .distantPast) }
    }

    func runs(owner: String, repo: String, branch: String) async throws -> [WorkflowRun] {
        let b = branch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? branch
        let r: RunsResponse = try await get("/repos/\(owner)/\(repo)/actions/runs?branch=\(b)&per_page=20")
        return r.workflow_runs
    }

    private func viewer() async throws -> String {
        if let viewerLogin { return viewerLogin }
        let me: Account = try await get("/user")
        viewerLogin = me.login
        return me.login
    }

    private func getAll<T: Decodable>(_ path: String) async throws -> [T] {
        var out: [T] = []
        for page in 1...10 {
            let chunk: [T] = try await get("\(path)&per_page=100&page=\(page)")
            out += chunk
            if chunk.count < 100 { break }
        }
        return out
    }

    // Las respuestas 304 (ETag) no consumen cuota de la API
    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "https://api.github.com" + path) else { throw GitHubError.badResponse }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(try currentToken())", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let cached = etags[path]
        if let cached { req.setValue(cached.etag, forHTTPHeaderField: "If-None-Match") }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.badResponse }

        switch http.statusCode {
        case 200:
            if let etag = http.value(forHTTPHeaderField: "ETag") { etags[path] = (etag, data) }
            return try decoder.decode(T.self, from: data)
        case 304:
            guard let cached else { throw GitHubError.badResponse }
            return try decoder.decode(T.self, from: cached.data)
        case 401:
            resetSession()
            throw GitHubError.unauthorized
        case 403 where http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0", 429:
            throw GitHubError.rateLimited
        default:
            throw GitHubError.http(http.statusCode, path)
        }
    }

    private func currentToken() throws -> String {
        if let token { return token }
        let t = try tokenProvider()
        token = t
        return t
    }
}
