import XCTest
@testable import SleepCore

final class ProfileBuilderTests: XCTestCase {

    func testMinutesFromNoon() {
        XCTAssertEqual(ProfileBuilder.minutesFromNoon(Fixtures.date(2026, 8, 20, 12, 0), calendar: Fixtures.calendar), 0)
        XCTAssertEqual(ProfileBuilder.minutesFromNoon(Fixtures.date(2026, 8, 20, 23, 0), calendar: Fixtures.calendar), 660)
        XCTAssertEqual(ProfileBuilder.minutesFromNoon(Fixtures.date(2026, 8, 20, 1, 0), calendar: Fixtures.calendar), 780)
        XCTAssertEqual(ProfileBuilder.minutesFromNoon(Fixtures.date(2026, 8, 20, 11, 59), calendar: Fixtures.calendar), 1439)
    }

    func testDateFromNoonMinuteRoundTrip() {
        let day = Fixtures.date(2026, 8, 20, 5, 0)
        let onset = ProfileBuilder.date(fromNoonMinute: 660, on: day, calendar: Fixtures.calendar)
        XCTAssertEqual(onset, Fixtures.date(2026, 8, 20, 23, 0))
        let wake = ProfileBuilder.date(fromNoonMinute: 1125, on: day, calendar: Fixtures.calendar)
        XCTAssertEqual(wake, Fixtures.date(2026, 8, 21, 6, 45))
    }

    func testMedianMinuteOddAndEven() {
        let dates = [
            Fixtures.date(2026, 8, 15, 23, 10),
            Fixtures.date(2026, 8, 16, 22, 50),
            Fixtures.date(2026, 8, 17, 23, 30)
        ]
        let median = ProfileBuilder.medianMinuteFromNoon(dates, calendar: Fixtures.calendar)
        XCTAssertEqual(median ?? -1, 670, accuracy: 0.001)
    }

    func testStageStatsAndBaselineGating() {
        let stats = ProfileBuilder.stageStats([20, 20, 20, 20])
        XCTAssertEqual(stats.mean, 20, accuracy: 0.001)
        XCTAssertEqual(stats.sd, 0, accuracy: 0.001)
        XCTAssertEqual(stats.count, 4)

        let empty = ProfileBuilder.baselineStats([20, 21], minimumCount: 5)
        XCTAssertEqual(empty.count, 0)

        let sufficient = ProfileBuilder.baselineStats([20, 21, 19, 20, 20], minimumCount: 5)
        XCTAssertEqual(sufficient.count, 5)
    }

    func testProfileWindowsSplitRecentAndBaseline() {
        var features: [NightFeatures] = []
        for day in 1...14 {
            let deepPct: Double = day <= 7 ? 15 : 20
            features.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day, 0),
                sessionStart: Fixtures.date(2026, 8, day, 23, 0),
                onset: Fixtures.date(2026, 8, day, 23, 0),
                offset: Fixtures.date(2026, 8, day + 1, 7, 0),
                tstMinutes: 420,
                deepPercent: deepPct,
                remPercent: 22
            ))
        }
        let profile = ProfileBuilder.profile(features: features, timelines: [], calendar: Fixtures.calendar)
        XCTAssertEqual(profile.recentNights.count, 7)
        XCTAssertEqual(profile.recentDeep.mean, 20, accuracy: 0.001)
        XCTAssertEqual(profile.baselineDeep.mean, 15, accuracy: 0.001)
        XCTAssertNil(profile.sri)
    }
}
