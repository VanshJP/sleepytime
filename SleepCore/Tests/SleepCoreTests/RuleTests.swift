import XCTest
@testable import SleepCore

final class RuleTests: XCTestCase {

    let anchor = Fixtures.date(2026, 8, 24, 12)

    func testCyclePeriodDetection() {
        let onset = Fixtures.date(2026, 8, 20, 23, 0)
        let segments: [SleepSegment] = [
            Fixtures.seg(onset, onset.addingTimeInterval(60 * 60), .core),
            Fixtures.seg(onset.addingTimeInterval(60 * 60), onset.addingTimeInterval(90 * 60), .rem),
            Fixtures.seg(onset.addingTimeInterval(90 * 60), onset.addingTimeInterval(150 * 60), .core),
            Fixtures.seg(onset.addingTimeInterval(150 * 60), onset.addingTimeInterval(180 * 60), .rem),
            Fixtures.seg(onset.addingTimeInterval(180 * 60), onset.addingTimeInterval(240 * 60), .core),
            Fixtures.seg(onset.addingTimeInterval(240 * 60), onset.addingTimeInterval(270 * 60), .rem)
        ]
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: segments)
        let f = FeatureExtractor.features(for: night, calendar: Fixtures.calendar)
        XCTAssertEqual(f?.cyclePeriodMinutes ?? -1, 90, accuracy: 0.001)
    }

    func testCyclePeriodNilWithSingleREM() {
        let onset = Fixtures.date(2026, 8, 20, 23, 0)
        let segments: [SleepSegment] = [
            Fixtures.seg(onset, onset.addingTimeInterval(3600), .core),
            Fixtures.seg(onset.addingTimeInterval(3600), onset.addingTimeInterval(5400), .rem)
        ]
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: segments)
        let f = FeatureExtractor.features(for: night, calendar: Fixtures.calendar)
        XCTAssertNil(f?.cyclePeriodMinutes)
    }

    func testCyclePeriodTimesPlateauEnd() {
        var recent: [NightFeatures] = []
        for day in 1...4 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 18, 0),
                sessionStart: Fixtures.date(2026, 8, day + 18, 23, 0),
                onset: Fixtures.date(2026, 8, day + 18, 23, 0),
                offset: Fixtures.date(2026, 8, day + 19, 8, 0),
                tstMinutes: 500,
                deepPercent: 18,
                remPercent: 22,
                deepCentroidMinutes: 260
            ))
            recent[recent.count - 1] = NightFeatures(
                nightKey: recent[recent.count - 1].nightKey,
                sessionStart: recent[recent.count - 1].sessionStart,
                onset: recent[recent.count - 1].onset,
                offset: recent[recent.count - 1].offset,
                tstMinutes: 500,
                tibMinutes: 540,
                sePercent: 92,
                solMinutes: 0,
                wasoMinutes: 10,
                deepMinutes: 90,
                remMinutes: 110,
                coreMinutes: 290,
                unspecifiedMinutes: 0,
                deepPercent: 18,
                remPercent: 22,
                remLatencyMinutes: 90,
                deepCentroidMinutes: 260,
                deepFrontRatio: nil,
                midsleep: recent[recent.count - 1].midsleep,
                awakenings: [],
                hasStageDetail: true,
                cyclePeriodMinutes: 95,
                timeZoneIdentifier: nil
            )
        }
        let profile = ProfileBuilder.profile(features: recent, timelines: [], calendar: Fixtures.calendar)
        XCTAssertEqual(profile.recentCyclePeriodMinutes ?? -1, 95, accuracy: 0.001)

        let lightsOut = Fixtures.date(2026, 8, 24, 23, 0)
        let wake = Fixtures.date(2026, 8, 25, 7, 0)
        let schedule = ScheduleEngine.generate(
            profile: profile,
            settings: ThermalSettings(),
            anchorDay: anchor,
            targetLightsOut: lightsOut,
            targetWake: wake,
            calendar: Fixtures.calendar
        )
        let plateau = schedule.phases.first { $0.id == "plateau" }!
        let plateauEndFromLightsOut = plateau.end.timeIntervalSince(lightsOut) / 60
        XCTAssertEqual(plateauEndFromLightsOut, 95 * 2.2, accuracy: 1)
    }

    func testHomeostaticRuleDeepensAfterShortNight() {
        var recent: [NightFeatures] = []
        for day in 1...5 {
            let tst: Double = day == 5 ? 330 : 450
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 17, 0),
                sessionStart: Fixtures.date(2026, 8, day + 17, 23, 0),
                onset: Fixtures.date(2026, 8, day + 17, 23, 0),
                offset: Fixtures.date(2026, 8, day + 18, 7, 0),
                tstMinutes: tst,
                deepPercent: 18,
                remPercent: 22
            ))
        }
        let profile = ProfileBuilder.profile(features: recent, timelines: [], calendar: Fixtures.calendar)
        XCTAssertEqual(profile.lastNightTSTMinutes ?? -1, 330, accuracy: 0.001)

        let lightsOut = Fixtures.date(2026, 8, 24, 23, 0)
        let wake = Fixtures.date(2026, 8, 25, 7, 0)
        let schedule = ScheduleEngine.generate(
            profile: profile,
            settings: ThermalSettings(),
            anchorDay: anchor,
            targetLightsOut: lightsOut,
            targetWake: wake,
            calendar: Fixtures.calendar
        )
        let plateau = schedule.phases.first { $0.id == "plateau" }!
        XCTAssertEqual(plateau.startOffsetC, -3.25, accuracy: 0.001)
        XCTAssertTrue(schedule.notes.contains { $0.localizedCaseInsensitiveContains("Short sleep") })
    }

    func testWakeRampNeverStartsBeforePredictedTmin() {
        let lightsOut = Fixtures.date(2026, 8, 24, 22, 0)
        let wake = Fixtures.date(2026, 8, 25, 4, 30)

        var male = ThermalSettings(isBiologicalSexFemale: false)
        male.wakeWarmthEnabled = true
        let maleSchedule = ScheduleEngine.generate(
            profile: .canonical(), settings: male, anchorDay: anchor,
            targetLightsOut: lightsOut, targetWake: wake, calendar: Fixtures.calendar
        )
        let maleRamp = maleSchedule.phases.last!
        let maleTmin = wake.addingTimeInterval(-2.0 * 3600)
        XCTAssertGreaterThanOrEqual(maleRamp.start.timeIntervalSince1970, maleTmin.timeIntervalSince1970 - 1)

        var female = ThermalSettings(isBiologicalSexFemale: true)
        female.wakeWarmthEnabled = true
        let femaleSchedule = ScheduleEngine.generate(
            profile: .canonical(), settings: female, anchorDay: anchor,
            targetLightsOut: lightsOut, targetWake: wake, calendar: Fixtures.calendar
        )
        let femaleRamp = femaleSchedule.phases.last!
        let femaleTmin = wake.addingTimeInterval(-3.5 * 3600)
        XCTAssertEqual(femaleRamp.start.timeIntervalSince1970, wake.addingTimeInterval(-45 * 60).timeIntervalSince1970, accuracy: 1)
        XCTAssertGreaterThanOrEqual(femaleRamp.start.timeIntervalSince1970, femaleTmin.timeIntervalSince1970)
    }

    func testTimezoneShiftDetectedAndAnchorsFollowDominantZone() {
        var cal = Fixtures.calendar
        cal.timeZone = TimeZone(identifier: "America/New_York")!

        func segs(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, tz: String) -> [TaggedSegment] {
            var c = Fixtures.calendar
            c.timeZone = TimeZone(identifier: tz)!
            let start = c.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
            let blocks = RegularityTestsHelper.contiguousSleep(from: start, hours: 8)
            return blocks.map { TaggedSegment(sourceID: "w", segment: $0, timeZoneIdentifier: tz) }
        }

        let home = segs(2026, 8, 10, 23, tz: "America/New_York")
        let home2 = segs(2026, 8, 11, 23, tz: "America/New_York")
        let trip1 = segs(2026, 8, 12, 20, tz: "Europe/Paris")
        let trip2 = segs(2026, 8, 13, 20, tz: "Europe/Paris")
        let trip3 = segs(2026, 8, 14, 20, tz: "Europe/Paris")

        let nights = NightBuilder.buildNights(tagged: home + home2 + trip1 + trip2 + trip3, calendar: cal)
        XCTAssertEqual(nights.count, 5)

        var features: [NightFeatures] = nights.compactMap { FeatureExtractor.features(for: $0, calendar: cal) }
        features = features.map { f in
            NightFeatures(
                nightKey: f.nightKey, sessionStart: f.sessionStart, onset: f.onset, offset: f.offset,
                tstMinutes: f.tstMinutes, tibMinutes: f.tibMinutes, sePercent: f.sePercent,
                solMinutes: f.solMinutes, wasoMinutes: f.wasoMinutes, deepMinutes: f.deepMinutes,
                remMinutes: f.remMinutes, coreMinutes: f.coreMinutes, unspecifiedMinutes: f.unspecifiedMinutes,
                deepPercent: 18, remPercent: 22, remLatencyMinutes: f.remLatencyMinutes,
                deepCentroidMinutes: f.deepCentroidMinutes, deepFrontRatio: f.deepFrontRatio,
                midsleep: f.midsleep, awakenings: f.awakenings, hasStageDetail: true,
                cyclePeriodMinutes: f.cyclePeriodMinutes, timeZoneIdentifier: f.timeZoneIdentifier
            )
        }

        let profile = ProfileBuilder.profile(features: features, timelines: nights, calendar: cal)
        XCTAssertEqual(profile.dominantTimeZoneID, "Europe/Paris")
        XCTAssertTrue(profile.timezoneShiftDetected)
    }
}

enum RegularityTestsHelper {
    static func contiguousSleep(from start: Date, hours: Double) -> [SleepSegment] {
        var segments: [SleepSegment] = []
        var cursor = start
        let stages: [SleepStage] = [.core, .deep, .core, .rem]
        var index = 0
        let end = start.addingTimeInterval(hours * 3600)
        while cursor < end {
            let next = min(cursor.addingTimeInterval(3600), end)
            segments.append(SleepSegment(start: cursor, end: next, stage: stages[index % stages.count]))
            index += 1
            cursor = next
        }
        return segments
    }
}
