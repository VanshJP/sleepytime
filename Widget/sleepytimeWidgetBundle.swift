import WidgetKit
import SwiftUI

enum WidgetTheme {
    static func tint(for phaseID: String) -> Color {
        switch phaseID {
        case "winddown", "wakeramp", "holdtowake": return Color(red: 1.0, green: 0.72, blue: 0.36)
        case "descent": return Color(red: 0.72, green: 0.66, blue: 1.0)
        case "plateau": return Color(red: 0.45, green: 0.78, blue: 1.0)
        case "remhold": return Color(red: 0.55, green: 0.95, blue: 0.75)
        default: return Color(red: 0.62, green: 0.90, blue: 0.94)
        }
    }

    static let background = LinearGradient(
        colors: [Color(red: 0.06, green: 0.09, blue: 0.24), Color(red: 0.14, green: 0.19, blue: 0.42)],
        startPoint: .top, endPoint: .bottom
    )
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedScheduleSnapshot?
    let isPlaceholder: Bool
}

struct ScheduleProvider: TimelineProvider {

    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: .now, snapshot: SharedScheduleStore.load(), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(ScheduleEntry(date: .now, snapshot: SharedScheduleStore.load(), isPlaceholder: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        guard let snapshot = SharedScheduleStore.load() else {
            completion(Timeline(entries: [ScheduleEntry(date: .now, snapshot: nil, isPlaceholder: false)], policy: .after(Date().addingTimeInterval(1800))))
            return
        }

        var entries: [ScheduleEntry] = [ScheduleEntry(date: .now, snapshot: snapshot, isPlaceholder: false)]
        var cursor = Date().addingTimeInterval(1800)
        let horizon = Date().addingTimeInterval(36 * 3600)
        while cursor < horizon {
            if let phase = snapshot.phases.first(where: { cursor >= $0.start && cursor < $0.end }) {
                entries.append(ScheduleEntry(date: cursor, snapshot: snapshot, isPlaceholder: false))
                cursor = min(phase.end, horizon)
            } else if let next = snapshot.phases.first(where: { $0.start > cursor }) {
                cursor = min(next.start, horizon)
            } else {
                break
            }
        }
        completion(Timeline(entries: entries, policy: .after(horizon)))
    }
}

struct TonightWidgetView: View {
    let entry: ScheduleEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { WidgetTheme.background }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot, let phase = snapshot.currentOrNextPhase(at: entry.date) {
            VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(phase.start <= entry.date ? "NOW" : "NEXT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(WidgetTheme.tint(for: phase.id))
                            .tracking(1)
                        Spacer()
                        if let side = snapshot.sideLabel {
                            Text(side)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Text(phase.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(phase.startDisplay == phase.endDisplay ? phase.startDisplay : "\(phase.startDisplay) → \(phase.endDisplay)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(WidgetTheme.tint(for: phase.id))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if phase.start <= entry.date {
                        ProgressView(value: entry.date.timeIntervalSince(phase.start) / max(1, phase.end.timeIntervalSince(phase.start)))
                            .progressViewStyle(.linear)
                            .tint(WidgetTheme.tint(for: phase.id))
                    } else {
                        Text("from \(phase.startDisplay)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if snapshot.nightsAnalyzed > 0 {
                        Text("from \(snapshot.nightsAnalyzed) analyzed nights")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(.white.opacity(0.7))
                    Text(entry.isPlaceholder ? "Tonight's plan" : "No schedule yet")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Open Goodnight")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TonightWidget", provider: ScheduleProvider()) { entry in
            TonightWidgetView(entry: entry)
        }
        .configurationDisplayName("Tonight's Plan")
        .description("Current bed-temperature phase from Goodnight.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TonightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TonightActivityAttributes.self) { context in
            LiveActivityCard(context: context)
                .padding(12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.phaseName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WidgetTheme.tint(for: context.state.tintName))
                        Text(context.state.setpointDisplay)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phaseEndDate, style: .timer)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: Date()...context.state.phaseEndDate, countsDown: true)
                        .tint(WidgetTheme.tint(for: context.state.tintName))
                }
            } compactLeading: {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(WidgetTheme.tint(for: context.state.tintName))
            } compactTrailing: {
                Text(context.state.setpointDisplay)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(WidgetTheme.tint(for: context.state.tintName))
            }
        }
    }
}

struct LiveActivityCard: View {
    let context: ActivityViewContext<TonightActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(context.state.phaseName, systemImage: "thermometer.medium")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetTheme.tint(for: context.state.tintName))
                Spacer()
                Text(context.state.setpointDisplay)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
            }
            ProgressView(timerInterval: Date()...context.state.phaseEndDate, countsDown: true)
                .tint(WidgetTheme.tint(for: context.state.tintName))
            HStack {
                Text("Goodnight")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("ends \(context.state.phaseEndDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

@main
struct sleepytimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        TonightLiveActivity()
    }
}
