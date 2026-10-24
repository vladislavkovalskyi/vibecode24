import SwiftUI
import VibeCore

struct PopoverView: View {
    @Bindable var controller: AwakeController
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}

    private var settings: AppSettings { controller.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 16)
                .padding(.bottom, 14)

            modePicker
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 14)

            Divider().overlay(Theme.line)

            AgentList(agents: controller.agents)
                .padding(.vertical, 10)

            Divider().overlay(Theme.line)

            LidStatus(controller: controller)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 12)

            Divider().overlay(Theme.line)

            footer
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 10)
        }
        .frame(width: Theme.popoverWidth)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            LaptopGlyph(look: controller.decision.look, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.opacity)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(L10n.reason(controller.decision, now: context.date))
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle(isOn: Binding(
                get: { settings.mode != .off },
                set: { on in controller.setMode(on ? settings.lastActiveMode : .off) }
            )) { EmptyView() }
                .toggleStyle(.switch)
                .tint(Theme.amber)
                .labelsHidden()
                .help(L10n.t(.toggleHint))
                .accessibilityLabel(L10n.t(.toggleHint))
        }
        .animation(Theme.stateChange, value: controller.decision.look)
    }

    private var title: String {
        switch controller.decision.look {
        case .holding: return L10n.t(.titleHolding)
        case .waiting: return L10n.t(.titleWaiting)
        case .off: return L10n.t(.titleOff)
        case .paused: return L10n.t(.titlePaused)
        }
    }

    // MARK: Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: Binding(
                get: { settings.mode == .off ? settings.lastActiveMode : settings.mode },
                set: { controller.setMode($0) }
            )) {
                Text(L10n.t(.modeAuto)).tag(AwakeMode.auto).help(L10n.t(.modeAutoHint))
                Text(L10n.t(.modeAlways)).tag(AwakeMode.always).help(L10n.t(.modeAlwaysHint))
                Text(L10n.t(.modeTimer)).tag(AwakeMode.timer).help(L10n.t(.modeTimerHint))
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.mode == .timer || (settings.mode == .off && settings.lastActiveMode == .timer) {
                TimerChips(selected: settings.timerMinutes) { controller.startTimer(minutes: $0) }
                    .transition(.opacity)
            }
        }
        .animation(Theme.stateChange, value: settings.mode)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if controller.stats.todayAwake > 0 {
                Text(L10n.t(.statsToday, L10n.duration(controller.stats.todayAwake),
                            L10n.duration(controller.stats.todayLidClosed)))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            HStack {
                Button(L10n.t(.settingsButton), action: openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button(L10n.t(.quit), action: quit)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }
}

/// Preset durations for the timer.
struct TimerChips: View {
    var selected: Int
    var pick: (Int) -> Void
    static let presets = [30, 60, 120, 240, 480]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.presets, id: \.self) { minutes in
                let isOn = minutes == selected
                Button { pick(minutes) } label: {
                    Text(L10n.duration(Double(minutes * 60)))
                        .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isOn ? Theme.amber.opacity(0.18) : Theme.tile)
                        )
                        .foregroundStyle(isOn ? Theme.amber : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
