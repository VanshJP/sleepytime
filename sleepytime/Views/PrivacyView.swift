import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Goodnight is built to never know who you are.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    bullet("No accounts, sign-in, email, or cloud sync.")
                    bullet("Sleep stages are read from Apple Health on this device only.")
                    bullet("Schedules, preferences, and learning state stay in on-device storage.")
                    bullet("No analytics SDKs, crash reporters, ad IDs, or network calls for product telemetry.")
                    bullet("Widgets and Live Activities share tonight's plan via a private App Group on the phone.")
                    bullet("You can revoke Health access anytime in iOS Settings → Privacy → Health.")

                    Text("If Apple asks for a privacy policy URL for App Store review, this screen is the policy: we collect nothing.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .nightScreen()
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.footnote)
                .foregroundStyle(NightTheme.mint)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
