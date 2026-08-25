import Foundation

public struct DeviceSetpoint: Sendable, Hashable {
    public let date: Date
    public let offsetC: Double
    public let displayValue: String
    public let instruction: String
}

public enum DeviceMapper {

    public static func map(schedule: ThermalSchedule, settings: ThermalSettings, useFahrenheit: Bool = false) -> [DeviceSetpoint] {
        schedule.setpoints.map { setpoint in
            deviceSetpoint(date: setpoint.date, offsetC: setpoint.offsetC, settings: settings, useFahrenheit: useFahrenheit)
        }
    }

    public static func absoluteCelsius(offsetC: Double, settings: ThermalSettings) -> Double? {
        switch settings.device {
        case .eightSleep, .waterPad:
            let raw = settings.neutralC + offsetC
            guard let minC = settings.device.minCelsius, let maxC = settings.device.maxCelsius else { return nil }
            return min(maxC, max(minC, raw))
        case .airConditioner:
            return nil
        case .generic:
            return nil
        }
    }

    public static func displayString(offsetC: Double, settings: ThermalSettings, useFahrenheit: Bool) -> String {
        switch settings.device {
        case .eightSleep, .waterPad:
            if let absolute = absoluteCelsius(offsetC: offsetC, settings: settings) {
                return temperatureString(celsius: absolute, useFahrenheit: useFahrenheit)
            }
            return offsetString(offsetC: offsetC, useFahrenheit: useFahrenheit)
        case .airConditioner:
            let clamped = max(-settings.device.acDeltaLimitC, min(settings.device.acDeltaLimitC, offsetC))
            let room = settings.roomSetpointC + clamped
            return temperatureString(celsius: room, useFahrenheit: useFahrenheit)
        case .generic:
            return offsetString(offsetC: offsetC, useFahrenheit: useFahrenheit)
        }
    }

    static func deviceSetpoint(date: Date, offsetC: Double, settings: ThermalSettings, useFahrenheit: Bool) -> DeviceSetpoint {
        let value = displayString(offsetC: offsetC, settings: settings, useFahrenheit: useFahrenheit)
        let action: String
        switch settings.device {
        case .eightSleep:
            action = "Set Eight Sleep to \(value)"
        case .waterPad:
            action = "Set pad to \(value)"
        case .airConditioner:
            action = "Set AC to \(value)"
        case .generic:
            action = "Apply \(value)"
        }
        return DeviceSetpoint(date: date, offsetC: offsetC, displayValue: value, instruction: "\(action)")
    }

    public static func temperatureString(celsius: Double, useFahrenheit: Bool) -> String {
        if useFahrenheit {
            return String(format: "%.0f°F", celsius * 9 / 5 + 32)
        }
        return String(format: "%.1f°C", celsius)
    }

    public static func offsetString(offsetC: Double, useFahrenheit: Bool) -> String {
        let rounded = (offsetC * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "neutral" }
        if useFahrenheit {
            return String(format: "%+.1f°F", rounded * 9 / 5)
        }
        return String(format: "%+.1f°C", rounded)
    }
}

public enum AutomationExporter {

    public static func exportText(schedule: ThermalSchedule, settings: ThermalSettings, calendar: Calendar = .current, useFahrenheit: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"

        var lines: [String] = []
        lines.append("GOODNIGHT: NIGHTLY THERMAL SCHEDULE")
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .medium
        dayFormatter.timeZone = calendar.timeZone
        lines.append("Generated \(dayFormatter.string(from: Date())) · all data processed on-device")
        lines.append("")
        lines.append("PHASES")

        let phaseFormatter = DateFormatter()
        phaseFormatter.dateFormat = "h:mm a"
        phaseFormatter.timeZone = calendar.timeZone

        for phase in schedule.phases {
            let from = phaseFormatter.string(from: phase.start)
            let to = phaseFormatter.string(from: phase.end)
            let startVal = DeviceMapper.displayString(offsetC: phase.startOffsetC, settings: settings, useFahrenheit: useFahrenheit)
            let endVal = DeviceMapper.displayString(offsetC: phase.endOffsetC, settings: settings, useFahrenheit: useFahrenheit)
            let tempPart = startVal == endVal ? startVal : "\(startVal) → \(endVal)"
            lines.append("\(from)–\(to)  \(phase.name): \(tempPart)")
            lines.append("   \(phase.rationale) [\(phase.evidence)]")
        }

        lines.append("")
        lines.append("TIMED SETPOINTS (\(settings.device.rawValue))")
        for setpoint in DeviceMapper.map(schedule: schedule, settings: settings, useFahrenheit: useFahrenheit) {
            lines.append("\(phaseFormatter.string(from: setpoint.date)) : \(setpoint.instruction)")
        }

        if !schedule.notes.isEmpty {
            lines.append("")
            lines.append("NOTES")
            schedule.notes.forEach { lines.append("• \($0)") }
        }

        lines.append("")
        lines.append("Not medical advice. Pre-wake warming is extrapolated from dawn-light studies; no direct thermal trial exists.")
        return lines.joined(separator: "\n")
    }

    public static func exportCSV(schedule: ThermalSchedule, settings: ThermalSettings) -> String {
        var rows: [String] = ["datetime_iso8601,offset_celsius,device_display"]
        let iso = ISO8601DateFormatter()
        for setpoint in DeviceMapper.map(schedule: schedule, settings: settings) {
            let display = setpoint.displayValue.replacingOccurrences(of: ",", with: "")
            rows.append("\(iso.string(from: setpoint.date)),\(String(format: "%.2f", setpoint.offsetC)),\(display)")
        }
        return rows.joined(separator: "\n")
    }
}
