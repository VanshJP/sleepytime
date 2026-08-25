import XCTest
@testable import SleepCore

final class LearningTests: XCTestCase {

    func testRecordGatesOnAdherence() {
        let state = LearningState()
        let schedule = ScheduleEngine.generate(
            profile: .canonical(),
            settings: ThermalSettings(),
            anchorDay: Fixtures.date(2026, 8, 24, 12),
            calendar: Fixtures.calendar
        )

        let adherent = Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 20, 0),
            sessionStart: schedule.lightsOut,
            onset: schedule.lightsOut,
            offset: schedule.lightsOut.addingTimeInterval(7 * 3600),
            tstMinutes: 420,
            deepPercent: 18,
            remPercent: 22
        )
        let offTime = Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 21, 0),
            sessionStart: schedule.lightsOut.addingTimeInterval(3 * 3600),
            onset: schedule.lightsOut.addingTimeInterval(3 * 3600),
            offset: schedule.lightsOut.addingTimeInterval(10 * 3600),
            tstMinutes: 420,
            deepPercent: 18,
            remPercent: 22
        )
        let shortSleep = Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 22, 0),
            sessionStart: schedule.lightsOut,
            onset: schedule.lightsOut,
            offset: schedule.lightsOut.addingTimeInterval(3 * 3600),
            tstMinutes: 150,
            deepPercent: 18,
            remPercent: 22
        )

        var next = AdaptiveLearning.record(state, night: adherent, schedule: schedule, calendar: Fixtures.calendar)
        XCTAssertTrue(next.nights[0].adherent)
        next = AdaptiveLearning.record(next, night: offTime, schedule: schedule, calendar: Fixtures.calendar)
        XCTAssertFalse(next.nights[1].adherent)
        next = AdaptiveLearning.record(next, night: shortSleep, schedule: schedule, calendar: Fixtures.calendar)
        XCTAssertFalse(next.nights[2].adherent)
    }

    func testRecordDeduplicatesNightKey() {
        let state = LearningState()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        let night = Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 20, 0),
            sessionStart: schedule.lightsOut,
            onset: schedule.lightsOut,
            offset: schedule.lightsOut.addingTimeInterval(7 * 3600),
            tstMinutes: 420,
            deepPercent: 18,
            remPercent: 22
        )
        let once = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        let twice = AdaptiveLearning.record(once, night: night, schedule: schedule, calendar: Fixtures.calendar)
        XCTAssertEqual(twice.nights.count, 1)
    }

    func makeAdherentTrial(deep: Double, around schedule: ThermalSchedule) -> [NightFeatures] {
        (0..<5).map { day in
            Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, 10 + day, 0),
                sessionStart: schedule.lightsOut,
                onset: schedule.lightsOut,
                offset: schedule.lightsOut.addingTimeInterval(7 * 3600),
                tstMinutes: 420,
                deepPercent: deep + Double(day % 2) * 0.1,
                remPercent: 22,
                sePercent: 92
            )
        }
    }

    func testEvaluateSuccessStepsUp() {
        var state = LearningState()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 19.2, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: 18.0, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 3.25, accuracy: 0.001)
        XCTAssertEqual(evaluated.lastStepC, 0.25, accuracy: 0.001)
        XCTAssertEqual(evaluated.completedTrials, 1)
        XCTAssertTrue(evaluated.nights.isEmpty)
    }

    func testEvaluateFailureReversesDirection() {
        var state = LearningState(candidateC: 3.25, lastStepC: 0.25, nights: [], completedTrials: 1)
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 16.5, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: 18.0, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 3.0, accuracy: 0.001)
        XCTAssertEqual(evaluated.lastStepC, -0.25, accuracy: 0.001)
        XCTAssertEqual(evaluated.completedTrials, 2)
    }

    func testEvaluateNeutralHoldsCandidate() {
        var state = LearningState()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 18.3, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: 18.0, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 3.0, accuracy: 0.001)
        XCTAssertEqual(evaluated.lastStepC, 0, accuracy: 0.001)
        XCTAssertEqual(evaluated.completedTrials, 0)
        XCTAssertTrue(evaluated.nights.isEmpty)
    }

    func testEvaluateRequiresBaseline() {
        var state = LearningState()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 19.5, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: nil, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 3.0, accuracy: 0.001)
        XCTAssertFalse(evaluated.nights.isEmpty)
    }

    func testEvaluateBlocksOnNonAdherentNight() {
        var state = LearningState()
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 19.5, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let off = Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 20, 0),
            sessionStart: schedule.lightsOut.addingTimeInterval(4 * 3600),
            onset: schedule.lightsOut.addingTimeInterval(4 * 3600),
            offset: schedule.lightsOut.addingTimeInterval(11 * 3600),
            tstMinutes: 420,
            deepPercent: 19.5,
            remPercent: 22
        )
        state = AdaptiveLearning.record(state, night: off, schedule: schedule)
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: 18.0, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 3.0, accuracy: 0.001)
        XCTAssertFalse(evaluated.nights.isEmpty)
    }

    func testCandidateClampedToBounds() {
        var state = LearningState(candidateC: 4.0, lastStepC: 0.25, nights: [], completedTrials: 9)
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        for night in makeAdherentTrial(deep: 19.9, around: schedule) {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: Fixtures.calendar)
        }
        let evaluated = AdaptiveLearning.evaluate(state, baselineDeepPercent: 18.0, baselineRemPercent: nil)
        XCTAssertEqual(evaluated.candidateC, 4.0, accuracy: 0.001)
        XCTAssertEqual(AdaptiveLearning.effectiveDepthC(evaluated), 4.0, accuracy: 0.001)
    }

    func testEngineConsumesAdaptiveDepth() {
        var settings = ThermalSettings()
        settings.adaptiveCoolDepthC = 3.75
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: Fixtures.date(2026, 8, 24, 12), calendar: Fixtures.calendar)
        let plateau = schedule.phases.first { $0.id == "plateau" }!
        XCTAssertEqual(plateau.startOffsetC, -3.75, accuracy: 0.001)
    }
}
