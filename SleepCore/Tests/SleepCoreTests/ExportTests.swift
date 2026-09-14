import XCTest
@testable import SleepCore

final class ExportTests: XCTestCase {

    let anchor = Fixtures.date(2026, 8, 24, 12, 0)

    func testExportTextContainsPhasesAndSetpoints() {
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(device: .eightSleep), anchorDay: anchor, calendar: Fixtures.calendar)
        let text = AutomationExporter.exportText(schedule: schedule, settings: ThermalSettings(device: .eightSleep), calendar: Fixtures.calendar)

        XCTAssertTrue(text.contains("GOODNIGHT"))
        XCTAssertTrue(text.contains("Wind-Down Warmth"))
        XCTAssertTrue(text.contains("Deep-Sleep Plateau"))
        XCTAssertTrue(text.contains("REM Cool Hold"))
        XCTAssertTrue(text.contains("Set Eight Sleep to 23.0°C"))
        XCTAssertTrue(text.contains("10:45 PM"))
        XCTAssertTrue(text.contains("Not medical advice"))
    }

    func testExportCSVRowCountsMatchSetpoints() {
        let settings = ThermalSettings()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)
        let csv = AutomationExporter.exportCSV(schedule: schedule, settings: settings)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, schedule.setpoints.count + 1)
        XCTAssertTrue(csv.hasPrefix("datetime_iso8601,offset_celsius,device_display"))
    }

    func testFahrenheitConversion() {
        XCTAssertEqual(DeviceMapper.temperatureString(celsius: 23.0, useFahrenheit: true), "73°F")
        XCTAssertEqual(DeviceMapper.temperatureString(celsius: 23.0, useFahrenheit: false), "23.0°C")
    }

    func testGenericDeviceShowsOffsets() {
        let settings = ThermalSettings(device: .generic)
        let display = DeviceMapper.displayString(offsetC: -3.0, settings: settings, useFahrenheit: false)
        XCTAssertEqual(display, "-3.0°C")
        let neutral = DeviceMapper.displayString(offsetC: 0.0, settings: settings, useFahrenheit: false)
        XCTAssertEqual(neutral, "neutral")
    }

    func testScheduleCodableRoundTrip() throws {
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(ThermalSchedule.self, from: data)
        XCTAssertEqual(decoded, schedule)
    }
}
