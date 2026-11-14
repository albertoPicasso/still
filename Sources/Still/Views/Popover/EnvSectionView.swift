import SwiftUI

struct EnvSectionView: View {
    let presentation: EnvPresentation
    let theme: Theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                StatusDot(color: theme.color(for: presentation.state))
                Text(presentation.label)
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(theme.text3)
                    .lineLimit(1)
                    .frame(minWidth: 34, alignment: .leading)
                Text(presentation.title)
                    .font(.still(17, .semibold))
                    .foregroundStyle(titleColor)
                Spacer()
                if let url = presentation.logURL {
                    Button("Ver log →") { openURL(url) }
                        .buttonStyle(.plain)
                        .font(.still(12, .medium))
                        .foregroundStyle(theme.text2)
                }
            }

            if let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(.still(13))
                    .foregroundStyle(theme.text3)
                    .padding(.leading, 70)
                    .padding(.top, 4)
            }

            ForEach(presentation.runs) { run in
                RunRowView(run: run, theme: theme)
                    .padding(.leading, 70)
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var titleColor: Color {
        switch presentation.tone {
        case .normal: theme.text
        case .busy: theme.apricotText
        case .failed: theme.red
        }
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .background(Circle().fill(color.opacity(0.16)).frame(width: 16, height: 16))
    }
}

struct RunRowView: View {
    let run: ActiveRun
    let theme: Theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let progress = RunProgress(run: run, now: tl.date)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(run.repo)
                        .font(.still(13))
                        .foregroundStyle(theme.text2)
                        .lineLimit(1)
                    Spacer()
                    timing(progress)
                        .font(.still(12))
                        .monospacedDigit()
                }
                ProgressLine(fraction: progress.fraction, theme: theme)
                    .padding(.top, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openURL(run.url) }
        .help("\(run.workflow) · \(run.actor)")
    }

    private func timing(_ p: RunProgress) -> Text {
        guard let elapsed = p.elapsed else { return Text("esperando").foregroundStyle(theme.text3) }
        let rest = p.remaining.map { Text(" · \($0)").foregroundStyle(theme.text3) } ?? Text("")
        return Text(elapsed).foregroundStyle(theme.text) + rest
    }
}

private struct ProgressLine: View {
    let fraction: Double
    let theme: Theme

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line)
                Capsule().fill(theme.apricot)
                    .frame(width: g.size.width * fraction)
                    .animation(.easeOut(duration: 0.6), value: fraction)
            }
        }
        .frame(height: 2)
    }
}
