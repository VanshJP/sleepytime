import XCTest
@testable import SleepCore

final class RegularityTests: XCTestCase {

    func testIdenticalBitmapsScore100() {
        let a = [Bool](repeating: true, count: 288)
        let sri = Regularity.sri(fromBitmaps: [(a, a)])
        XCTAssertEqual(sri ?? 0, 100, accuracy: 0.001)
    }

    func testComplementaryBitmapsScore0() {
        let a = [Bool](repeating: true, count: 288)
        let b = [Bool](repeating: false, count: 288)
        let sri = Regularity.sri(fromBitmaps: [(a, b)])
        XCTAssertEqual(sri ?? 0, 0, accuracy: 0.001)
    }

    func testHalfMatchScores50() {
        let a: [Bool] = [true, false, true, false]
        let b: [Bool] = [true, false, false, true]
        let sri = Regularity.sri(fromBitmaps: [(a, b)])
        XCTAssertEqual(sri ?? 0, 50, accuracy: 0.001)
    }

    func testTwoIdenticalNightsGiveSRIOf100() {
        let night1Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 20, 22, 0), hours: 8)
        let night2Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 21, 22, 0), hours: 8)

        let nights = NightBuilder.buildNights(
            tagged: (night1Segments + night2Segments).map { TaggedSegment(sourceID: "w", segment: $0) },
            calendar: Fixtures.calendar
        )
        XCTAssertEqual(nights.count, 2)
        let sri = Regularity.sri(nights: nights, calendar: Fixtures.calendar)
        XCTAssertEqual(sri ?? 0, 100, accuracy: 0.001)
    }

    func testShiftedNightReducesSRI() {
        let night1Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 20, 22, 0), hours: 8)
        let night2Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 22, 0, 0), hours: 8)

        let nights = NightBuilder.buildNights(
            tagged: (night1Segments + night2Segments).map { TaggedSegment(sourceID: "w", segment: $0) },
            calendar: Fixtures.calendar
        )
        let sri = Regularity.sri(nights: nights, calendar: Fixtures.calendar)
        XCTAssertNotNil(sri)
        XCTAssertEqual(sri ?? 0, (72.0 + 168.0) / 288.0 * 100, accuracy: 0.5)
        XCTAssertLessThan(sri ?? 0, 100)
    }

    func testNonConsecutiveNightsProduceNil() {
        let night1Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 20, 22, 0), hours: 8)
        let night2Segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 25, 22, 0), hours: 8)
        let nights = NightBuilder.buildNights(
            tagged: (night1Segments + night2Segments).map { TaggedSegment(sourceID: "w", segment: $0) },
            calendar: Fixtures.calendar
        )
        XCTAssertNil(Regularity.sri(nights: nights, calendar: Fixtures.calendar))
    }

    func testSingleNightProducesNil() {
        let segments = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 20, 22, 0), hours: 8)
        let nights = NightBuilder.buildNights(
            tagged: segments.map { TaggedSegment(sourceID: "w", segment: $0) },
            calendar: Fixtures.calendar
        )
        XCTAssertNil(Regularity.sri(nights: nights, calendar: Fixtures.calendar))
    }

}
