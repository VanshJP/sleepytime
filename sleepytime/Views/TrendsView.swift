import SwiftUI
import Charts
import SleepCore

struct TrendsView: View {
    @Environment(AppModel.self) private var model

    private var recentNights: [NightFeatures] {
        model.features
            .filter { $0.isUsableNight }
            .sorted { $0.nightKey > $1.nightKey }
            .prefix(14)
            .reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if recentNights.isEmpty {
                        emptyCard
                    } else {
                        summaryRow
                        if let audit = model.lastNightAudit {
                            thermalAlignmentCard(audit)
                        }
                        regularityCard
                        architectureChartCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .nightScreen()
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.bottom, 110, for: .scrollContent)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(NightTheme.lavender)
            Text("No nights yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Sleep a few nights with your watch on, or explore with demo data from Settings.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.top, 30)
    }

    private var summaryRow: some View {
        let profile = model.profile
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Avg sleep", value: formatHours(profile.recentTST.mean), icon: "bed.double.fill", tint: NightTheme.lavender)
            statCard(title: "Efficiency", value: profile.recentSE.count > 0 ? String(format: "%.0f%%", profile.recentSE.mean) : "n/a", icon: "checkmark.seal.fill", tint: NightTheme.mint)
            statCard(title: "Deep share", value: percentString(profile.recentDeep), icon: "moon.circle.fill", tint: NightTheme.ice)
            statCard(title: "REM share", value: percentString(profile.recentRem), icon: "brain.filled.head.profile", tint: NightTheme.amber)
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
            Text("last \(model.profile.recentNights.count) nights")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }

    private func percentString(_ stats: StageStats) -> String {
        stats.count > 0 ? String(format: "%.1f%%", stats.mean) : "n/a"
    }

    private func formatHours(_ minutes: Double) -> String {
        guard minutes > 0 else { return "n/a" }
        let hours = Int(minutes / 60)
        let mins = Int(minutes.rounded()) % 60
        return "\(hours)h \(mins)m"
    }

    private func thermalAlignmentCard(_ audit: NightThermalAudit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cooling vs stages", systemImage: "thermometer.variable.and.figure")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(audit.summary)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 16) {
                if let deep = audit.deepMeanOffsetC {
                    stageTempChip("Deep", deep, NightTheme.ice)
                }
                if let rem = audit.remMeanOffsetC {
                    stageTempChip("REM", rem, NightTheme.amber)
                }
                if let core = audit.coreMeanOffsetC {
                    stageTempChip("Core", core, NightTheme.lavender)
                }
                Spacer()
            }
            Text("Compares last night's stages to the temperature the schedule was commanding — all on-device.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .glassCard()
    }

    private func stageTempChip(_ label: String, _ offset: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(String(format: "%+.1f°C", offset))
                .font(.callout.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
        }
    }

    private var regularityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Schedule regularity", systemImage: "repeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let sri = model.profile.sri {
                    Text(String(format: "%.0f / 100", sri))
                        .font(.callout.monospacedDigit().weight(.bold))
                        .foregroundStyle(sriColor)
                }
            }
            Gauge(value: model.profile.sri ?? 0, in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(sriColor)
            Text(regularityExplainer)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
        }
        .glassCard()
    }

    private var sriColor: Color {
        switch model.profile.consistencyClass {
        case .high: return NightTheme.mint
        case .moderate: return NightTheme.frost
        case .low: return NightTheme.amber
        }
    }

    private var regularityExplainer: String {
        switch model.profile.consistencyClass {
        case .high:
            return "Your bedtime and wake time are consistent night to night. That's when personalized stage targeting works best."
        case .moderate:
            return "Some night-to-night drift. The schedule anchors to your median times and personalizes cautiously."
        case .low:
            return "Large timing shifts between nights. Goodnight uses the canonical template until your rhythm stabilizes. A fixed wake time is the single highest-leverage change."
        }
    }

    private var architectureChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sleep stages by night", systemImage: "chart.stack.depth.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Chart(recentNights, id: \.nightKey) { night in
                ForEach(stageSeries(for: night), id: \.stage) { series in
                    BarMark(
                        x: .value("Night", night.nightKey, unit: .day),
                        y: .value("Minutes", series.minutes)
                    )
                    .foregroundStyle(by: .value("Stage", series.stage.rawValue.capitalized))
                    .cornerRadius(2)
                }
            }
            .chartForegroundStyleScale(
                domain: ["Deep", "Rem", "Core", "Unspecified"],
                range: [
                    NightTheme.stageColor(.deep),
                    NightTheme.stageColor(.rem),
                    NightTheme.stageColor(.core),
                    NightTheme.stageColor(.unspecified)
                ]
            )
            .chartLegend(.hidden)
            .frame(height: 180)

            legendChips

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Consumer wearables estimate deep sleep less reliably than total sleep time, so compare nights against your own average, not absolute numbers.")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.4))
        }
        .glassCard()
    }

    private var legendChips: some View {
        HStack(spacing: 12) {
            chip("Deep", NightTheme.stageColor(.deep))
            chip("REM", NightTheme.stageColor(.rem))
            chip("Core", NightTheme.stageColor(.core))
            chip("Unspecified", NightTheme.stageColor(.unspecified))
            Spacer()
        }
    }

    private func chip(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
    }


    private struct SeriesEntry {
        let stage: SleepStage
        let minutes: Double
    }

    private func stageSeries(for night: NightFeatures) -> [SeriesEntry] {
        [
            SeriesEntry(stage: .deep, minutes: night.deepMinutes),
            SeriesEntry(stage: .rem, minutes: night.remMinutes),
            SeriesEntry(stage: .core, minutes: night.coreMinutes),
            SeriesEntry(stage: .unspecified, minutes: night.unspecifiedMinutes)
        ]
    }
}
