import SwiftUI

struct AutomationExportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste these timed steps into Apple Shortcuts, your Eight Sleep app, a ChiliPad schedule, or a smart-thermostat automation.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))

                    Text(model.automationText(for: .primary))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.35)))

                    Button {
                        model.copyAutomation()
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy to clipboard", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(18)
            }
            .navigationTitle("Automation plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: copied)
        }
        .preferredColorScheme(.dark)
    }
}
