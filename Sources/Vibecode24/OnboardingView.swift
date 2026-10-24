import SwiftUI
import VibeCore

struct OnboardingView: View {
    @Bindable var controller: AwakeController
    var done: () -> Void
    @State var look: LaptopGlyph.Look = .off
    @State private var installing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LaptopGlyph(look: look, size: 96)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { look = .holding }
                }

            Text(L10n.t(.onboardingTitle))
                .font(.system(size: 22, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                point("menubar.rectangle", L10n.t(.onboardingPoint1))
                point("lock.shield", L10n.t(.onboardingPoint2))
                point("arrow.uturn.backward.circle", L10n.t(.onboardingPoint3))
            }

            HStack {
                Button(L10n.t(.notNow), action: done)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    installing = true
                    Task {
                        await controller.installHelper(prompt: L10n.t(.adminPrompt))
                        installing = false
                        if controller.helperInstalled { done() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if installing { ProgressView().controlSize(.small) }
                        Text(L10n.t(.allowLidMode))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.amber)
                .keyboardShortcut(.defaultAction)
                .disabled(installing)
            }
        }
        .padding(28)
        .frame(width: 440)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
