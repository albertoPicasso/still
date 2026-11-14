import Foundation

enum Formatters {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.unitsStyle = .full
        return f
    }()

    static func relative(_ date: Date, to now: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    // 2:34 o 1:02:09
    static func clock(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds))
        return t >= 3600
            ? String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
            : String(format: "%d:%02d", t / 60, t % 60)
    }
}
