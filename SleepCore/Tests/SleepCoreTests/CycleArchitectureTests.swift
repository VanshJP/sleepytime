import XCTest
@testable import SleepCore

final class CycleArchitectureTests: XCTestCase {

    func testCycleCountClampedAndWeightsConserveTotals() {
        let cycles = CycleArchitecture.build(asleepMinutes: 450, deepMinutes: 90, remMinutes: 100)
        XCTAssertEqual(cycles.count, 5) // 450/90 = 5
        let deepSum = cycles.map(\.deepMinutes).reduce(0, +)
        let remSum = cycles.map(\.remMinutes).reduce(0, +)
        XCTAssertEqual(deepSum, 90, accuracy: 0.01)
        XCTAssertEqual(remSum, 100, accuracy: 0.01)
        XCTAssertGreaterThan(cycles[0].deepMinutes, cycles[4].deepMinutes)
        XCTAssertLessThan(cycles[0].remMinutes, cycles[4].remMinutes)
    }

    func testDeepWindowEndsOnDeepHeavyCycles() {
        let cycles = CycleArchitecture.build(asleepMinutes: 450, deepMinutes: 90, remMinutes: 100)
        let end = CycleArchitecture.deepWindowEndMinutes(cycles: cycles)
        XCTAssertNotNil(end)
        XCTAssertGreaterThanOrEqual(end!, cycles[1].endMinutes - 0.01)
    }

    func testCoolFractionPeaksThenFloorsAtRem() {
        let cycles = CycleArchitecture.build(asleepMinutes: 450, deepMinutes: 90, remMinutes: 100)
        let first = CycleArchitecture.coolFraction(for: cycles[0], among: cycles)
        let last = CycleArchitecture.coolFraction(for: cycles[cycles.count - 1], among: cycles)
        XCTAssertEqual(first, 1.0, accuracy: 0.001)
        XCTAssertEqual(last, 0.7, accuracy: 0.001)
    }

    func testConfidenceIncreasesWithData() {
        let empty = ScheduleConfidence.score(profile: .canonical(), goodNightsUsed: 0)
        XCTAssertLessThan(empty, 0.3)

        var nights: [NightFeatures] = []
        for day in 1...10 {
            nights.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day, 0),
                sessionStart: Fixtures.date(2026, 8, day, 23, 0),
                onset: Fixtures.date(2026, 8, day, 23, 15),
                offset: Fixtures.date(2026, 8, day + 1, 7, 0),
                tstMinutes: 450,
                deepPercent: 18,
                remPercent: 22
            ))
        }
        let profile = ProfileBuilder.profile(features: nights, timelines: [], calendar: Fixtures.calendar)
        let scored = ScheduleConfidence.score(profile: profile, goodNightsUsed: profile.goodNightsUsed)
        XCTAssertGreaterThan(scored, empty)
    }
}
