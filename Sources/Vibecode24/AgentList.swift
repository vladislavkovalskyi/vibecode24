import SwiftUI
import VibeCore

struct AgentList: View {
    var agents: [AgentRowModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L10n.t(.agents)).sectionLabel()
                if !agents.isEmpty {
                    Text("\(agents.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Theme.gutter)

            if agents.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t(.noAgents)).font(.system(size: 12, weight: .medium))
                    Text(L10n.t(.noAgentsHint))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(agents) { AgentRow(agent: $0) }
                }
            }
        }
        .animation(Theme.stateChange, value: agents.map(\.id))
    }
}

struct AgentRow: View {
    var agent: AgentRowModel

    var body: some View {
        HStack(spacing: 10) {
            Monogram(text: agent.definition.monogram, active: agent.isWorking)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(agent.definition.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if agent.sessionCount > 1 {
                        Text("×\(agent.sessionCount)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .help(L10n.t(.sessionsCount, agent.sessionCount))
                    }
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(statusLine(now: context.date))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(agent.isWorking ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(.secondary))
                }
            }
            Spacer(minLength: 8)
            Sparkline(values: agent.history, active: agent.isWorking)
                .frame(width: 62, height: 16)
                .help(String(format: "%.0f%% CPU", agent.cpuPercent))
        }
        .padding(.horizontal, Theme.gutter)
        .frame(height: 40)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func statusLine(now: Date) -> String {
        let state = agent.isWorking ? L10n.t(.working) : L10n.t(.idle)
        return "\(state) · \(L10n.duration(now.timeIntervalSince(agent.since)))"
    }
}

struct Monogram: View {
    var text: String
    var active: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.tile))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(active ? Theme.led : Color.primary.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
    }
}

/// CPU of the agent's process tree, one bar per tick, newest on the right.
struct Sparkline: View {
    var values: [Double]
    var active: Bool
    private let slots = 20

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 1
            let width = (size.width - gap * CGFloat(slots - 1)) / CGFloat(slots)
            let padded = Array(repeating: 0.0, count: max(0, slots - values.count)) + values.suffix(slots)
            // Scale to the busiest moment, with a floor so a quiet agent stays flat.
            let top = max(25, (padded.max() ?? 0) * 1.1)
            for (index, value) in padded.enumerated() {
                let height = max(1.5, CGFloat(value / top) * size.height)
                let rect = CGRect(x: CGFloat(index) * (width + gap), y: size.height - height,
                                  width: width, height: height)
                let color: Color = active && value >= 3 ? Theme.amber : Color.primary.opacity(0.18)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.8), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
