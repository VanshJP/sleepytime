import XCTest
@testable import SleepCore

final class FeatureTests: XCTestCase {

    func testDetailedNightFeaturesMatchHandComputation() throws {
        let segments = Fixtures.detailedNight(onsetYear: 2026, onsetMonth: 8, onsetDay: 20)
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: segments)
        let f = try XCTUnwrap(FeatureExtractor.features(for: night, calendar: Fixtures.calendar))

        XCTAssertEqual(f.sessionStart, Fixtures.date(2026, 8, 20, 22, 30))
        XCTAssertEqual(f.onset, Fixtures.date(2026, 8, 20, 23, 0))
        XCTAssertEqual(f.offset, Fixtures.date(2026, 8, 21, 4, 40))

        XCTAssertEqual(f.solMinutes, 30, accuracy: 0.001)
        XCTAssertEqual(f.tstMinutes, 330, accuracy: 0.001)
        XCTAssertEqual(f.tibMinutes, 370, accuracy: 0.001)
        XCTAssertEqual(f.wasoMinutes, 10, accuracy: 0.001)
        XCTAssertEqual(f.sePercent, 330.0 / 370.0 * 100, accuracy: 0.01)

        XCTAssertEqual(f.deepMinutes, 90, accuracy: 0.001)
        XCTAssertEqual(f.remMinutes, 120, accuracy: 0.001)
        XCTAssertEqual(f.coreMinutes, 120, accuracy: 0.001)
        XCTAssertEqual(f.deepPercent, 90.0 / 330 * 100, accuracy: 0.01)
        XCTAssertEqual(f.remPercent, 120.0 / 330 * 100, accuracy: 0.01)

        XCTAssertEqual(f.remLatencyMinutes ?? -1, 160, accuracy: 0.001)
        XCTAssertEqual(f.deepCentroidMinutes ?? -1, 128 + 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(f.deepFrontRatio ?? -1, 2.0 / 3.0, accuracy: 0.001)

        XCTAssertEqual(f.awakenings.count, 1)
        let cluster = try XCTUnwrap(f.awakenings.first)
        XCTAssertEqual(cluster.startOffsetMinutes, 150, accuracy: 0.001)
        XCTAssertEqual(cluster.durationMinutes, 10, accuracy: 0.001)

        XCTAssertTrue(f.hasStageDetail)
        XCTAssertTrue(f.isUsableNight)
    }

    func testOverlappingDuplicatesAreUnioned() {
        let deep1 = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 0, 0), .deep)
        let deepDup = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 30), Fixtures.date(2026, 8, 21, 0, 30), .deep)
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: [deep1, deepDup])
        let f = FeatureExtractor.features(for: night, calendar: Fixtures.calendar)
        XCTAssertEqual(f?.deepMinutes ?? -1, 90, accuracy: 0.001)
        XCTAssertEqual(f?.tstMinutes ?? -1, 90, accuracy: 0.001)
    }

    func testUnspecifiedOnlyNightHasNoStageDetail() {
        let a = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 3, 0), .unspecified)
        let awake = Fixtures.seg(Fixtures.date(2026, 8, 21, 3, 0), Fixtures.date(2026, 8, 21, 3, 10), .awake)
        let b = Fixtures.seg(Fixtures.date(2026, 8, 21, 3, 10), Fixtures.date(2026, 8, 21, 5, 0), .unspecified)
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: [a, awake, b])
        let f = FeatureExtractor.features(for: night, calendar: Fixtures.calendar)

        XCTAssertEqual(f?.tstMinutes ?? -1, 350, accuracy: 0.001)
        XCTAssertEqual(f?.hasStageDetail, false)
        XCTAssertEqual(f?.deepPercent ?? -1, 0, accuracy: 0.001)
    }

    func testShortNightFlaggedUnusable() {
        let a = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 0, 30), .core)
        let night = NightTimeline(nightKey: Fixtures.date(2026, 8, 20, 0), segments: [a])
        let f = FeatureExtractor.features(for: night, calendar: Fixtures.calendar)
        XCTAssertEqual(f?.isUsableNight, false)
    }

    func testPhaseInterpolation() {
        let phase = ThermalPhase(
            id: "test", name: "t", rationale: "r", evidence: "e",
            start: Fixtures.date(2026, 8, 20, 22, 0),
            end: Fixtures.date(2026, 8, 20, 23, 0),
            startOffsetC: 1.5, endOffsetC: -3
        )
        XCTAssertEqual(phase.offset(at: phase.start), 1.5, accuracy: 0.0001)
        XCTAssertEqual(phase.offset(at: phase.end), -3, accuracy: 0.0001)
        XCTAssertEqual(phase.offset(at: Fixtures.date(2026, 8, 20, 22, 30)), -0.75, accuracy: 0.0001)
        XCTAssertEqual(phase.offset(at: Fixtures.date(2026, 8, 19, 12)), 1.5, accuracy: 0.0001)
        XCTAssertEqual(phase.offset(at: Fixtures.date(2026, 8, 21, 12)), -3, accuracy: 0.0001)
    }
}
