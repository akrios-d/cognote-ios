import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var step = 0
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                page(title: "onboarding.step1.title", message: "onboarding.step1.body") {
                    Text(L("app.title"))
                        .font(.serif(.largeTitle, weight: .bold))
                        .foregroundStyle(Palette.accent)
                }
                .tag(0)

                page(title: "onboarding.step2.title", message: "onboarding.step2.body") {
                    VStack(alignment: .leading, spacing: 12) {
                        spaceRow("workspace.quickFilms", width: 180, color: Palette.accent)
                        spaceRow("workspace.quickBooks", width: 140, color: Palette.pos)
                        spaceRow("workspace.quickSeries", width: 110, color: Palette.neg)
                    }
                }
                .tag(1)

                page(title: "onboarding.step3.title", message: "onboarding.step3.body") {
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            sentimentChip("− " + L("list.sentimentNegative"), active: false, color: Palette.neg)
                            sentimentChip("+ " + L("list.sentimentPositive"), active: true, color: Palette.accent)
                        }
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { dot in
                                Circle()
                                    .fill(dot <= 4 ? Palette.accent : Palette.starOff)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                if step > 0 {
                    Button(L("onboarding.back")) {
                        withAnimation { step -= 1 }
                    }
                    .foregroundStyle(Palette.ink2)
                }
                Spacer()
                Button {
                    if step < totalSteps - 1 {
                        withAnimation { step += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(L(step < totalSteps - 1 ? "onboarding.next" : "onboarding.done"))
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .foregroundStyle(Palette.onAccent)
                        .background(Capsule().fill(Palette.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func page<Visual: View>(
        title: String,
        message: String,
        @ViewBuilder visual: () -> Visual
    ) -> some View {
        VStack(spacing: 28) {
            Spacer()
            visual()
                .frame(height: 160)
            VStack(spacing: 14) {
                Text(L(title))
                    .font(.serif(.title, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(L(message))
                    .font(.body)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    private func spaceRow(_ key: String, width: CGFloat, color: Color) -> some View {
        HStack(spacing: 12) {
            Capsule().fill(color).frame(width: 4, height: 28)
            Text(L(key))
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: width + 60, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
    }

    private func sentimentChip(_ text: String, active: Bool, color: Color) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(active ? Palette.onAccent : color)
            .background(Capsule().fill(active ? color : Palette.surface))
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }
}
