import SwiftUI

// Modos de diagnóstico por línea de comandos. Nunca tocan los perfiles guardados.
//   --dump [owner repo,repo]   estado real en texto
//   --snapshot <dir>           PNG del desplegable y de Ajustes con datos de ejemplo
//   --icon <dir>               carpeta AppIcon.iconset lista para iconutil
@MainActor
enum DebugCommands {
    private static let args = CommandLine.arguments

    static var isActive: Bool { args.contains("--dump") || args.contains("--snapshot") || args.contains("--icon") }

    static func run(_ app: AppContainer) {
        Task { @MainActor in
            if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
                await snapshot(to: args[i + 1])
            } else if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
                writeIconSet(to: args[i + 1])
            } else if let i = args.firstIndex(of: "--dump") {
                await dump(app, owner: arg(i + 1), repos: arg(i + 2))
            }
            exit(0)
        }
    }

    private static func arg(_ i: Int) -> String? { i < args.count ? args[i] : nil }

    private static func dump(_ app: AppContainer, owner: String?, repos: String?) async {
        if let owner, let repos {
            let p = app.store.add(owner: owner)
            app.store.update(p.id) { $0.repos = repos.split(separator: ",").map(String.init) }
        } else if let real = UserDefaultsProfilePersistence().load().profiles.first {
            // Sin argumentos: copia en memoria del primer perfil guardado
            let p = app.store.add(owner: real.owner)
            app.store.update(p.id) { $0 = Profile(id: p.id, name: real.name, owner: real.owner,
                                                  repos: real.repos, environments: real.environments) }
        }
        await app.status.refreshOnce()
        print(app.status.debugDescription)
    }

    private static func snapshot(to dir: String) async {
        let demo = Profile(name: "demo", owner: "acme", repos: ["api", "web"])
        let app = AppContainer(persistence: InMemoryProfilePersistence(initial: [demo, Profile(name: "personal", owner: "me")]),
                               github: DemoGitHubService())
        for (name, mood) in [("calm", 0.0), ("busy", 0.5), ("storm", 1.0)] {
            app.status.loadDemo(mood: mood)
            for scheme in [ColorScheme.light, .dark] {
                let renderer = ImageRenderer(content: PopoverView(viewModel: app.status).environment(\.colorScheme, scheme))
                renderer.scale = 2
                if let png = renderer.nsImage.flatMap(pngData) {
                    try? png.write(to: URL(fileURLWithPath: "\(dir)/popover-\(name)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }
        app.status.loadDemo()

        for (name, mood) in [("calm", 0.0), ("busy", 0.5), ("storm", 1.0)] {
            for scheme in [ColorScheme.light, .dark] {
                let view = SeaView(mood: mood, night: scheme == .dark)
                    .frame(width: 330, height: 144)
                    .background(Theme.of(scheme).background)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                if let png = renderer.nsImage.flatMap(pngData) {
                    try? png.write(to: URL(fileURLWithPath: "\(dir)/sea-\(name)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }

        // Los controles de AppKit solo se pintan dentro de una ventana real
        let host = NSHostingView(rootView: SettingsView(viewModel: app.settings))
        let window = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: 680, height: 620),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        try? await Task.sleep(for: .seconds(2))
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/settings.png"))
        }
    }

    private static func writeIconSet(to dir: String) {
        let set = "\(dir)/AppIcon.iconset"
        try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
        let sizes: [(name: String, px: CGFloat)] = [
            ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
            ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
            ("512x512", 512), ("512x512@2x", 1024),
        ]
        for (name, px) in sizes {
            let renderer = ImageRenderer(content: AppIconView(side: px))
            renderer.scale = 1
            if let png = renderer.nsImage.flatMap(pngData) {
                try? png.write(to: URL(fileURLWithPath: "\(set)/icon_\(name).png"))
            }
        }
    }

    private static func pngData(_ image: NSImage) -> Data? {
        image.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }?.representation(using: .png, properties: [:])
    }
}

private struct DemoGitHubService: GitHubService {
    func owners() async throws -> [String] { ["me", "acme"] }

    func repos(owner: String) async throws -> [Repo] {
        ["api", "web", "mobile", "infra", "docs"].enumerated().map { i, name in
            Repo(name: name, archived: false, pushed_at: Date().addingTimeInterval(Double(-i) * 7200))
        }
    }

    func runs(owner: String, repo: String, branch: String) async throws -> [WorkflowRun] { [] }

    func resetSession() async {}
}
