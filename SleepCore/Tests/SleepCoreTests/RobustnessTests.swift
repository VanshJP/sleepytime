import XCTest
@testable import SleepCore

final class RobustnessTests: XCTestCase {

    let anchor = Fixtures.date(2026, 8, 24, 12)

    func testDSTFallBackKeepsRegularityAndKeys() {
        var cal = Fixtures.calendar
        cal.timeZone = TimeZone(identifier: "America/New_York")!

        func nightSegments(month: Int, day: Int) -> [TaggedSegment] {
            let start = cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 21))!
            let blocks = RegularityTestsHelper.contiguousSleep(from: start, hours: 8)
            return blocks.map { TaggedSegment(sourceID: "w", segment: $0) }
        }

        let nights = NightBuilder.buildNights(
            tagged: nightSegments(month: 10, day: 30) + nightSegments(month: 10, day: 31)
                + nightSegments(month: 11, day: 1) + nightSegments(month: 11, day: 2),
            calendar: cal
        )
        XCTAssertEqual(nights.count, 4)
        XCTAssertEqual(nights.map(\.nightKey), [
            cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: 10, day: 30))!),
            cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: 10, day: 31))!),
            cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!),
            cal.startOfDay(for: cal.date(from: DateComponents(year: 2026, month: 11, day: 2))!)
        ])

        let sri = Regularity.sri(nights: nights, calendar: cal)
        XCTAssertEqual(sri ?? 0, 100, accuracy: 0.001)
    }

    func testPropertyBasedScheduleInvariants() {
        var rng = SeededGenerator(seed: 0xFEED)

        for iteration in 0..<200 {
            let nightCount = Int.random(in: 0...12, using: &rng)
            var features: [NightFeatures] = []
            for day in 0..<nightCount {
                let tst = Double.random(in: 180...560, using: &rng)
                let sol = Double.random(in: 0...45, using: &rng)
                let deep = Double.random(in: 5...30, using: &rng)
                let rem = Double.random(in: 8...30, using: &rng)
                let onsetHour = Double.random(in: 21...26, using: &rng)
                let onset = Fixtures.date(2026, 8, 1, 0).addingTimeInterval((Double(day) * 24 + onsetHour) * 3600)
                features.append(Fixtures.makeFeatures(
                    nightKey: Fixtures.date(2026, 8, 1 + day, 0),
                    sessionStart: onset.addingTimeInterval(-sol * 60),
                    onset: onset,
                    offset: onset.addingTimeInterval(tst * 60),
                    tstMinutes: tst,
                    deepPercent: deep,
                    remPercent: rem,
                    sePercent: Double.random(in: 70...99, using: &rng),
                    solMinutes: sol,
                    deepCentroidMinutes: Double.random(in: 40...320, using: &rng)
                ))
            }

            var settings = ThermalSettings(
                device: DeviceKind.allCases.randomElement(using: &rng)!,
                neutralC: Double.random(in: 15...32, using: &rng),
                roomSetpointC: Double.random(in: 16...26, using: &rng),
                thermalBias: Double.random(in: -1...1, using: &rng),
                wakeWarmthEnabled: Bool.random(using: &rng),
                hotSleeperMode: Bool.random(using: &rng),
                isBiologicalSexFemale: [true, false, nil].randomElement(using: &rng)!,
                adaptiveCoolDepthC: Bool.random(using: &rng) ? Double.random(in: 1...5, using: &rng) : nil
            )

            let lightsOut = Fixtures.date(2026, 8, 24, Int.random(in: 21...23, using: &rng), [0, 15, 30, 45].randomElement(using: &rng)!)
            let wake = lightsOut.addingTimeInterval(Double.random(in: 4 * 3600...11 * 3600, using: &rng))

            let profile = ProfileBuilder.profile(features: features, timelines: [], calendar: Fixtures.calendar)
            let schedule = ScheduleEngine.generate(
                profile: profile,
                settings: settings,
                anchorDay: anchor,
                targetLightsOut: lightsOut,
                targetWake: wake,
                calendar: Fixtures.calendar
            )

            XCTAssertFalse(schedule.phases.isEmpty, "iteration \(iteration)")
            for window in zip(schedule.phases, schedule.phases.dropFirst()) {
                XCTAssertLessThanOrEqual(window.0.end, window.1.start + 0.5, "iteration \(iteration)")
                XCTAssertLessThan(window.0.start, window.0.end, "iteration \(iteration) zero-length phase")
            }
            XCTAssertEqual(schedule.phases.last?.end ?? .distantPast, schedule.wake, "iteration \(iteration)")

            let bias = settings.thermalBias * ScheduleEngine.biasScaleC
            for phase in schedule.phases {
                XCTAssertGreaterThanOrEqual(phase.startOffsetC, -4.0 + bias - 0.001, "iteration \(iteration)")
                XCTAssertLessThanOrEqual(phase.endOffsetC, 2.5 + bias + 0.001, "iteration \(iteration)")
            }

            let dates = schedule.setpoints.map(\.date)
            for window in zip(dates, dates.dropFirst()) {
                XCTAssertLessThan(window.0, window.1, "iteration \(iteration) setpoints not increasing")
            }

            settings.thermalBias = 0
            let again = ScheduleEngine.generate(
                profile: profile,
                settings: settings,
                anchorDay: anchor,
                targetLightsOut: lightsOut,
                targetWake: wake,
                calendar: Fixtures.calendar
            )
            let baseline = ScheduleEngine.generate(
                profile: profile,
                settings: settings,
                anchorDay: anchor,
                targetLightsOut: lightsOut,
                targetWake: wake,
                calendar: Fixtures.calendar
            )
            XCTAssertEqual(again, baseline, "iteration \(iteration) not deterministic")
        }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
