import AppIntents
import SleepCore

struct NextSetpointIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Bed Setpoint"
    static let description = IntentDescription(
        "Speaks the current or next phase of tonight's Goodnight temperature schedule, including the target setpoint."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = SharedScheduleStore.load() else {
            return .result(dialog: "No schedule yet. Open Goodnight to generate one.")
        }
        let now = Date()
        if let active = snapshot.phases.first(where: { now >= $0.start && now < $0.end }) {
            let temp = active.startDisplay == active.endDisplay
                ? active.startDisplay
                : "\(active.startDisplay) shifting to \(active.endDisplay)"
            return .result(dialog: "\(active.name) is active now: \(temp), until \(active.endDisplay).")
        }
        if let next = snapshot.phases.first(where: { $0.start > now }) {
            let temp = next.startDisplay == next.endDisplay
                ? next.startDisplay
                : "\(next.startDisplay) shifting to \(next.endDisplay)"
            return .result(dialog: "\(next.name) begins at \(next.startDisplay): \(temp).")
        }
        return .result(dialog: "Tonight's schedule is complete. It refreshes after your next sleep.")
    }
}

struct TonightPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Tonight's Bed Plan"
    static let description = IntentDescription("Reads out all phases of tonight's Goodnight temperature schedule.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = SharedScheduleStore.load(), !snapshot.phases.isEmpty else {
            return .result(dialog: "No schedule yet. Open Goodnight to generate one.")
        }
        let lines = snapshot.phases.map { phase in
            let temp = phase.startDisplay == phase.endDisplay
                ? phase.startDisplay
                : "\(phase.startDisplay) to \(phase.endDisplay)"
            return "\(phase.name), \(phase.startDisplay) to \(phase.endDisplay): \(temp)"
        }
        return .result(dialog: "Tonight: \(lines.joined(separator: ". ")).")
    }
}

struct GoodnightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextSetpointIntent(),
            phrases: [
                "Next bed setpoint in \(.applicationName)",
                "Bed temperature in \(.applicationName)"
            ],
            shortTitle: "Next Setpoint",
            systemImageName: "thermometer.medium"
        )
        AppShortcut(
            intent: TonightPlanIntent(),
            phrases: [
                "Tonight's bed plan in \(.applicationName)"
            ],
            shortTitle: "Tonight's Plan",
            systemImageName: "moon.stars.fill"
        )
    }
}
