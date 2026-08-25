import XCTest
@testable import SleepCore

final class NightBuilderTests: XCTestCase {

    func testPostMidnightOnsetGroupsIntoPreviousNight() {
        let late = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 1, 0), .core)
        let early = Fixtures.seg(Fixtures.date(2026, 8, 21, 1, 0), Fixtures.date(2026, 8, 21, 5, 0), .rem)
        let nights = NightBuilder.buildNights(
            tagged: [TaggedSegment(sourceID: "watch", segment: late), TaggedSegment(sourceID: "watch", segment: early)],
            calendar: Fixtures.calendar
        )
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].nightKey, Fixtures.date(2026, 8, 20, 0))
        XCTAssertEqual(nights[0].segments.count, 2)
    }

    func testNapsExcludedButMainSleepKept() {
        let mainSleep = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 7, 0), .unspecified)
        let afternoonNap = Fixtures.seg(Fixtures.date(2026, 8, 20, 14, 0), Fixtures.date(2026, 8, 20, 15, 0), .unspecified)
        let longDaytimeSleep = Fixtures.seg(Fixtures.date(2026, 8, 19, 13, 0), Fixtures.date(2026, 8, 19, 21, 0), .unspecified)

        let all = [mainSleep, afternoonNap, longDaytimeSleep].map { TaggedSegment(sourceID: "w", segment: $0) }
        let nights = NightBuilder.buildNights(tagged: all, calendar: Fixtures.calendar)

        let keys = nights.map(\.nightKey)
        XCTAssertTrue(keys.contains(Fixtures.date(2026, 8, 20, 0)))
        XCTAssertTrue(keys.contains(Fixtures.date(2026, 8, 19, 0)))
        let aug20 = nights.first { $0.nightKey == Fixtures.date(2026, 8, 20, 0) }
        XCTAssertEqual(aug20?.segments.count, 1)
        XCTAssertEqual(aug20?.segments.first?.start, mainSleep.start)
    }

    func testSourceArbitrationPrefersPreferredSource() {
        let watchSeg = Fixtures.seg(Fixtures.date(2026, 8, 20, 23, 0), Fixtures.date(2026, 8, 21, 6, 0), .deep)
        let phoneSeg = Fixtures.seg(Fixtures.date(2026, 8, 20, 22, 0), Fixtures.date(2026, 8, 21, 9, 0), .unspecified)

        let tagged = [
            TaggedSegment(sourceID: "com.apple.watch", segment: watchSeg),
            TaggedSegment(sourceID: "com.phone", segment: phoneSeg)
        ]

        let withPreference = NightBuilder.buildNights(tagged: tagged, preferredSources: ["com.apple.watch"], calendar: Fixtures.calendar)
        XCTAssertEqual(withPreference[0].segments.map(\.stage), [.deep])

        let byDuration = NightBuilder.buildNights(tagged: tagged, preferredSources: [], calendar: Fixtures.calendar)
        XCTAssertEqual(byDuration[0].segments.map(\.stage), [.unspecified])
    }

    func testLargeGapSplitsSessions() {
        let a = Fixtures.seg(Fixtures.date(2026, 8, 20, 22, 0), Fixtures.date(2026, 8, 21, 1, 0), .core)
        let b = Fixtures.seg(Fixtures.date(2026, 8, 21, 5, 0), Fixtures.date(2026, 8, 21, 7, 0), .rem)
        let sessions = NightBuilder.sessions(from: [a, b], gapTolerance: 120 * 60)
        XCTAssertEqual(sessions.count, 2)
    }

    func testSmallGapMergesSessions() {
        let a = Fixtures.seg(Fixtures.date(2026, 8, 20, 22, 0), Fixtures.date(2026, 8, 21, 1, 0), .core)
        let b = Fixtures.seg(Fixtures.date(2026, 8, 21, 2, 0), Fixtures.date(2026, 8, 21, 7, 0), .rem)
        let sessions = NightBuilder.sessions(from: [a, b], gapTolerance: 120 * 60)
        XCTAssertEqual(sessions.count, 1)
    }

    func testEmptyInputProducesNoNights() {
        XCTAssertTrue(NightBuilder.buildNights(tagged: [], calendar: Fixtures.calendar).isEmpty)
    }
}
