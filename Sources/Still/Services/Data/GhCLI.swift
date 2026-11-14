import Foundation

// Acceso a la CLI `gh` del ordenador; de ella sale el token
enum GhCLI {
    enum Failure: LocalizedError {
        case notInstalled, notLoggedIn

        var errorDescription: String? {
            switch self {
            case .notInstalled: "No encuentro gh. Instálalo con `brew install gh`."
            case .notLoggedIn: "gh no tiene sesión. Ejecuta `gh auth login` en la terminal."
            }
        }
    }

    static func token() throws -> String {
        guard let gh = path() else { throw Failure.notInstalled }
        guard let t = run(gh, ["auth", "token"]), !t.isEmpty else { throw Failure.notLoggedIn }
        return t
    }

    // Las apps abiertas desde Finder no heredan el PATH de la terminal
    static func path() -> String? {
        let known = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        if let p = known.first(where: FileManager.default.isExecutableFile(atPath:)) { return p }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard let p = run(shell, ["-lc", "command -v gh"]), FileManager.default.isExecutableFile(atPath: p) else {
            return nil
        }
        return p
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        // Leer antes de esperar: si el pipe se llena, waitUntilExit no vuelve nunca
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
