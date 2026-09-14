import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(NightTheme.coolGradient)
                        .symbolEffect(.breathe)
                    Text("Goodnight")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your sleep data already knows when you run warm and cool. Goodnight turns it into a nightly temperature schedule for any bed, pad, or AC.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 48)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                VStack(spacing: 14) {
                    featureRow(icon: "waveform.path.ecg", tint: NightTheme.ice,
                               title: "Reads your sleep architecture",
                               text: "Deep, REM, and core stages straight from Apple Health. Nothing leaves your phone.")
                    featureRow(icon: "timer", tint: NightTheme.mint,
                               title: "Times the temperature",
                               text: "Warm wind-down, cool plateau through your deep-sleep window, steady hold through REM, gentle wake ramp.")
                    featureRow(icon: "bed.double.fill", tint: NightTheme.amber,
                               title: "Works with what you own",
                               text: "Eight Sleep, ChiliPad, or a smart AC. Export timed setpoints as automations.")
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                Spacer(minLength: 12)

                Button {
                    Task { await model.connectAndLoad() }
                } label: {
                    HStack {
                        if model.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "heart.text.square.fill")
                        }
                        Text("Connect Apple Health")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)

                Button {
                    Task { await model.enterDemoMode() }
                } label: {
                    Text("Explore with demo nights")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.glass)

                if let error = model.errorText {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(NightTheme.ember)
                        .multilineTextAlignment(.center)
                }

                Text("No accounts. No servers. No tracking.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 22)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .task {
            // If Health was already authorized on a prior launch, skip the gate.
            await model.bootstrap()
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }
}
