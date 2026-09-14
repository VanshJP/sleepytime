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
            let temp = tempPhrase(active)
            return .result(dialog: "\(active.name) is active now at \(temp), until \(active.endDisplay).")
        }
        if let next = snapshot.phases.first(where: { $0.start > now }) {
            let temp = tempPhrase(next)
            return .result(dialog: "\(next.name) begins at \(next.startDisplay), targeting \(temp).")
        }
        return .result(dialog: "Tonight's schedule is complete. It refreshes after your next sleep.")
    }

    private func tempPhrase(_ phase: SharedPhaseInfo) -> String {
        let start = phase.startTempDisplay.isEmpty ? phase.startDisplay : phase.startTempDisplay
        let end = phase.endTempDisplay.isEmpty ? phase.endDisplay : phase.endTempDisplay
        return start == end ? start : "\(start) shifting to \(end)"
    }
}

struct TonightPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Tonight's Bed Plan"
    static let description = IntentDescription("Reads out all phases of tonight's Goodnight temperature schedule.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = SharedScheduleStore.load(), !snapshot.phases.isEmpty else {
            return .result(dialog: "No schedule yet. Open Goodnight to generate one.")
        }
        let lines = snapshot.phases.map { phase -> String in
            let startT = phase.startTempDisplay.isEmpty ? "" : phase.startTempDisplay
            let endT = phase.endTempDisplay.isEmpty ? startT : phase.endTempDisplay
            let temp: String
            if startT.isEmpty {
                temp = ""
            } else if startT == endT {
                temp = ": \(startT)"
            } else {
                temp = ": \(startT) to \(endT)"
            }
            return "\(phase.name), \(phase.startDisplay) to \(phase.endDisplay)\(temp)"
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
