import XCTest
@testable import SleepCore

final class EngineTests: XCTestCase {

    let anchor = Fixtures.date(2026, 8, 24, 12, 0)

    func testCanonicalScheduleShape() {
        let schedule = ScheduleEngine.generate(
            profile: .canonical(),
            settings: ThermalSettings(device: .eightSleep),
            anchorDay: anchor,
            calendar: Fixtures.calendar
        )

        XCTAssertEqual(schedule.lightsOut, Fixtures.date(2026, 8, 24, 22, 45))
        XCTAssertEqual(schedule.wake, Fixtures.date(2026, 8, 25, 6, 45))

        let ids = schedule.phases.map(\.id)
        XCTAssertEqual(ids, ["winddown", "descent", "plateau", "remhold", "wakeramp"])

        let windDown = schedule.phases[0]
        XCTAssertEqual(windDown.startOffsetC, 1.5, accuracy: 0.001)
        XCTAssertEqual(windDown.end.timeIntervalSince(windDown.start), 90 * 60, accuracy: 1)

        let descent = schedule.phases[1]
        XCTAssertEqual(descent.startOffsetC, 1.5, accuracy: 0.001)
        XCTAssertEqual(descent.endOffsetC, -3.0, accuracy: 0.001)
        XCTAssertEqual(descent.end.timeIntervalSince(descent.start), 45 * 60, accuracy: 1)

        let plateau = schedule.phases[2]
        XCTAssertEqual(plateau.startOffsetC, -3.0, accuracy: 0.001)
        XCTAssertEqual(plateau.endOffsetC, -3.0, accuracy: 0.001)
        XCTAssertEqual(plateau.end.timeIntervalSince(plateau.start), (210.0 - 45.0) * 60, accuracy: 1)

        let remHold = schedule.phases[3]
        XCTAssertEqual(remHold.endOffsetC, -3.0 * 0.7, accuracy: 0.001)
        XCTAssertGreaterThan(remHold.startOffsetC, plateau.endOffsetC - 0.001)

        let wakeRamp = schedule.phases[4]
        XCTAssertEqual(wakeRamp.endOffsetC, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(wakeRamp.endOffsetC, wakeRamp.startOffsetC)

        for window in zip(schedule.phases, schedule.phases.dropFirst()) {
            XCTAssertLessThanOrEqual(window.0.end, window.1.start + 0.5)
            XCTAssertLessThan(window.0.start, window.0.end)
        }
    }

    func testPlateauIsColdestAndWindDownWarmest() {
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        let mins = schedule.phases.map { min($0.startOffsetC, $0.endOffsetC) }
        let maxs = schedule.phases.map { max($0.startOffsetC, $0.endOffsetC) }
        let globalMin = mins.min() ?? 99
        let globalMax = maxs.max() ?? -99
        XCTAssertEqual(globalMin, -3.0, accuracy: 0.001)
        XCTAssertEqual(globalMax, 1.5, accuracy: 0.001)
        for phase in schedule.phases {
            if phase.id == "plateau" {
                XCTAssertLessThanOrEqual(phase.startOffsetC, globalMin + 0.0001)
            }
        }
    }

    func testSetpointsCoverWindowOn30MinGridWithBoundaries() {
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertFalse(schedule.setpoints.isEmpty)

        let dates = schedule.setpoints.map(\.date)
        XCTAssertEqual(dates.first, schedule.phases[0].start)
        XCTAssertEqual(dates.last, schedule.wake)

        for window in zip(dates, dates.dropFirst()) {
            XCTAssertLessThan(window.0, window.1)
        }

        for phase in schedule.phases {
            XCTAssertTrue(dates.contains(phase.start), "missing boundary \(phase.start)")
            XCTAssertTrue(dates.contains(phase.end), "missing boundary \(phase.end)")
        }

        let windowStart = schedule.phases[0].start
        let gridStep = 1800.0
        var cursor = windowStart.addingTimeInterval(gridStep - windowStart.timeIntervalSince1970.truncatingRemainder(dividingBy: gridStep))
        while cursor <= schedule.wake {
            XCTAssertTrue(dates.contains(where: { abs($0.timeIntervalSince(cursor)) < 1 }), "missing grid mark \(cursor)")
            cursor = cursor.addingTimeInterval(gridStep)
        }
    }

    func testDeterminism() {
        let profile = ProfileBuilder.profile(features: sampleFeatures(), timelines: [], calendar: Fixtures.calendar)
        let s1 = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        let s2 = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertEqual(s1, s2)
    }

    func testAirConditionerDropsHeatPhaseAndClampsDelta() {
        var settings = ThermalSettings(device: .airConditioner, roomSetpointC: 20)
        settings.thermalBias = -1
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)

        XCTAssertFalse(schedule.phases.contains { $0.id == "winddown" })

        let mapped = DeviceMapper.map(schedule: schedule, settings: settings)
        for setpoint in mapped {
            if setpoint.displayValue.hasSuffix("°C") {
                let value = Double(setpoint.displayValue.dropLast(2)) ?? 0
                XCTAssertGreaterThanOrEqual(value, 18)
                XCTAssertLessThanOrEqual(value, 22)
            }
        }
    }

    func testWaterDeviceMappingClampsToRange() {
        var settings = ThermalSettings(device: .eightSleep, neutralC: 15)
        settings.thermalBias = -1
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)
        let mapped = DeviceMapper.map(schedule: schedule, settings: settings)
        for setpoint in mapped {
            let value = Double(setpoint.displayValue.dropLast(2)) ?? 0
            XCTAssertGreaterThanOrEqual(value, 13)
            XCTAssertLessThanOrEqual(value, 43)
        }
        XCTAssertTrue(mapped.contains { $0.displayValue == "13.0°C" })
    }

    func testFemalePriorWarmsTemplate() {
        let female = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(isBiologicalSexFemale: true), anchorDay: anchor, calendar: Fixtures.calendar)
        let male = ScheduleEngine.generate(profile: .canonical(), settings: ThermalSettings(isBiologicalSexFemale: false), anchorDay: anchor, calendar: Fixtures.calendar)

        XCTAssertEqual(female.phases[0].startOffsetC, 2.0, accuracy: 0.001)
        XCTAssertEqual(female.phases[2].startOffsetC, -2.0, accuracy: 0.001)
        XCTAssertEqual(male.phases[2].startOffsetC, -3.0, accuracy: 0.001)
    }

    func testThermalBiasShiftsAllOffsets() {
        var settings = ThermalSettings()
        settings.thermalBias = 1
        let warm = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)
        settings.thermalBias = -1
        let cool = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)
        settings.thermalBias = 0
        let neutral = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)

        for (w, n) in zip(warm.setpoints, neutral.setpoints) {
            XCTAssertEqual(w.offsetC - n.offsetC, 1.5, accuracy: 0.001)
        }
        for (c, n) in zip(cool.setpoints, neutral.setpoints) {
            XCTAssertEqual(c.offsetC - n.offsetC, -1.5, accuracy: 0.001)
        }
    }

    func testLongLatencyExtendsWindDownAndRamp() {
        let features = [Fixtures.makeFeatures(
            nightKey: Fixtures.date(2026, 8, 23, 0),
            sessionStart: Fixtures.date(2026, 8, 23, 22, 30),
            onset: Fixtures.date(2026, 8, 23, 23, 10),
            offset: Fixtures.date(2026, 8, 24, 7, 0),
            tstMinutes: 420,
            deepPercent: 18,
            remPercent: 22,
            solMinutes: 35
        )]
        let profile = ProfileBuilder.profile(features: features, timelines: [], calendar: Fixtures.calendar)
        let schedule = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)

        let windDown = schedule.phases[0]
        XCTAssertEqual(windDown.end.timeIntervalSince(windDown.start), 120 * 60, accuracy: 1)
        let descent = schedule.phases[1]
        XCTAssertEqual(descent.end.timeIntervalSince(descent.start), 60 * 60, accuracy: 1)
        XCTAssertTrue(schedule.notes.contains { $0.localizedCaseInsensitiveContains("25 minutes") || $0.localizedCaseInsensitiveContains("fall asleep") })
    }

    func testDeepDeficitDeepensPlateauOnlyWithBaseline() {
        var recent: [NightFeatures] = []
        for day in 1...7 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 14, 0),
                sessionStart: Fixtures.date(2026, 8, day + 14, 23, 0),
                onset: Fixtures.date(2026, 8, day + 14, 23, 0),
                offset: Fixtures.date(2026, 8, day + 15, 7, 0),
                tstMinutes: 420,
                deepPercent: 13,
                remPercent: 22
            ))
        }
        var baseline: [NightFeatures] = []
        for day in 1...10 {
            baseline.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 7, day + 4, 0),
                sessionStart: Fixtures.date(2026, 7, day + 4, 23, 0),
                onset: Fixtures.date(2026, 7, day + 4, 23, 0),
                offset: Fixtures.date(2026, 7, day + 5, 7, 0),
                tstMinutes: 420,
                deepPercent: 21,
                remPercent: 22
            ))
        }

        let withBaseline = ProfileBuilder.profile(features: baseline + recent, timelines: [], calendar: Fixtures.calendar)
        let deepened = ScheduleEngine.generate(profile: withBaseline, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertEqual(deepened.phases[2].startOffsetC, -3.5, accuracy: 0.001)

        let withoutBaseline = ProfileBuilder.profile(features: recent, timelines: [], calendar: Fixtures.calendar)
        let untouched = ScheduleEngine.generate(profile: withoutBaseline, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertEqual(untouched.phases[2].startOffsetC, -3.0, accuracy: 0.001)
    }

    func testLowConsistencyGatesPersonalization() {
        var recent: [NightFeatures] = []
        for day in 1...7 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 14, 0),
                sessionStart: Fixtures.date(2026, 8, day + 14, 23, 0),
                onset: Fixtures.date(2026, 8, day + 14, 23, 0),
                offset: Fixtures.date(2026, 8, day + 15, 7, 0),
                tstMinutes: 420,
                deepPercent: 13,
                remPercent: 22
            ))
        }
        var baseline: [NightFeatures] = []
        for day in 1...10 {
            baseline.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 7, day + 4, 0),
                sessionStart: Fixtures.date(2026, 7, day + 4, 23, 0),
                onset: Fixtures.date(2026, 7, day + 4, 23, 0),
                offset: Fixtures.date(2026, 7, day + 5, 7, 0),
                tstMinutes: 420,
                deepPercent: 21,
                remPercent: 22
            ))
        }

        let timelineA = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 20, 22, 0), hours: 8)
        let timelineB = Fixtures.contiguousSleep(from: Fixtures.date(2026, 8, 22, 4, 0), hours: 8)
        let irregularTimelines = NightBuilder.buildNights(
            tagged: (timelineA + timelineB).map { TaggedSegment(sourceID: "w", segment: $0) },
            calendar: Fixtures.calendar
        )

        let profile = ProfileBuilder.profile(features: baseline + recent, timelines: irregularTimelines, calendar: Fixtures.calendar)
        XCTAssertEqual(profile.consistencyClass, .low)

        let gated = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertEqual(gated.phases.first { $0.id == "plateau" }?.startOffsetC ?? 99, -3.0, accuracy: 0.001)
        XCTAssertTrue(gated.notes.contains { $0.localizedCaseInsensitiveContains("regularity") })
    }

    func testEarlyAwakeningsEasePlateau() {
        var recent: [NightFeatures] = []
        let cluster = AwakeningCluster(startOffsetMinutes: 100, endOffsetMinutes: 110, durationMinutes: 10)
        for day in 1...5 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 16, 0),
                sessionStart: Fixtures.date(2026, 8, day + 16, 23, 0),
                onset: Fixtures.date(2026, 8, day + 16, 23, 0),
                offset: Fixtures.date(2026, 8, day + 17, 7, 0),
                tstMinutes: 420,
                deepPercent: 18,
                remPercent: 22,
                awakenings: [cluster]
            ))
        }
        let profile = ProfileBuilder.profile(features: recent, timelines: [], calendar: Fixtures.calendar)
        let eased = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertEqual(eased.phases[2].startOffsetC, -2.5, accuracy: 0.001)
    }

    func testREMDeficitRaisesFloor() {
        var recent: [NightFeatures] = []
        for day in 1...6 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 15, 0),
                sessionStart: Fixtures.date(2026, 8, day + 15, 23, 0),
                onset: Fixtures.date(2026, 8, day + 15, 23, 0),
                offset: Fixtures.date(2026, 8, day + 16, 7, 0),
                tstMinutes: 420,
                deepPercent: 18,
                remPercent: 17
            ))
        }
        var baseline: [NightFeatures] = []
        for day in 1...8 {
            baseline.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 7, day + 8, 0),
                sessionStart: Fixtures.date(2026, 7, day + 8, 23, 0),
                onset: Fixtures.date(2026, 7, day + 8, 23, 0),
                offset: Fixtures.date(2026, 7, day + 9, 7, 0),
                tstMinutes: 420,
                deepPercent: 18,
                remPercent: 24
            ))
        }
        let profile = ProfileBuilder.profile(features: baseline + recent, timelines: [], calendar: Fixtures.calendar)
        let raised = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)
        let remHold = raised.phases.first { $0.id == "remhold" }!
        // Softened toward neutral: 35% of the Kim 70%-of-cool-depth floor.
        XCTAssertEqual(remHold.endOffsetC, (-3.0 * 0.7) * 0.35, accuracy: 0.05)
    }

    func testHotSleeperDisablesWakeRamp() {
        let settings = ThermalSettings(hotSleeperMode: true)
        let schedule = ScheduleEngine.generate(profile: .canonical(), settings: settings, anchorDay: anchor, calendar: Fixtures.calendar)
        XCTAssertNil(schedule.phases.first { $0.id == "wakeramp" })
        XCTAssertNotNil(schedule.phases.first { $0.id == "holdtowake" })
        XCTAssertEqual(schedule.phases.last?.endOffsetC ?? 99, -3.0 * 0.7, accuracy: 0.001)
    }

    func testDeepCentroidShiftsPlateauEnd() {
        let centroidMinutes = 200.0
        var recent: [NightFeatures] = []
        for day in 1...3 {
            recent.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 20, 0),
                sessionStart: Fixtures.date(2026, 8, day + 20, 23, 0),
                onset: Fixtures.date(2026, 8, day + 20, 23, 0),
                offset: Fixtures.date(2026, 8, day + 21, 9, 0),
                tstMinutes: 480,
                deepPercent: 18,
                remPercent: 22,
                deepCentroidMinutes: centroidMinutes
            ))
        }
        let profile = ProfileBuilder.profile(features: recent, timelines: [], calendar: Fixtures.calendar)
        let schedule = ScheduleEngine.generate(profile: profile, settings: ThermalSettings(), anchorDay: anchor, calendar: Fixtures.calendar)

        let plateau = schedule.phases.first { $0.id == "plateau" }!
        let plateauLengthMinutes = plateau.end.timeIntervalSince(plateau.start) / 60
        XCTAssertEqual(plateauLengthMinutes + 45, 300, accuracy: 1)
        XCTAssertEqual(schedule.metrics.deepCentroidMinutesUsed ?? -1, centroidMinutes, accuracy: 0.001)
    }

    func testShortNightKeepsPhasesOrdered() {
        let lightsOut = Fixtures.date(2026, 8, 24, 23, 0)
        let wake = Fixtures.date(2026, 8, 25, 3, 0)
        let schedule = ScheduleEngine.generate(
            profile: .canonical(),
            settings: ThermalSettings(),
            anchorDay: anchor,
            targetLightsOut: lightsOut,
            targetWake: wake,
            calendar: Fixtures.calendar
        )

        for window in zip(schedule.phases, schedule.phases.dropFirst()) {
            XCTAssertLessThanOrEqual(window.0.end, window.1.start + 0.5)
        }
        for phase in schedule.phases {
            XCTAssertLessThan(phase.start, phase.end, "degenerate phase \(phase.id)")
        }
        XCTAssertEqual(schedule.phases.last?.end, wake)
    }

    func testExplicitTargetsOverrideAnchors() {
        let lightsOut = Fixtures.date(2026, 8, 24, 23, 15)
        let wake = Fixtures.date(2026, 8, 25, 6, 30)
        let schedule = ScheduleEngine.generate(
            profile: .canonical(),
            settings: ThermalSettings(),
            anchorDay: anchor,
            targetLightsOut: lightsOut,
            targetWake: wake,
            calendar: Fixtures.calendar
        )
        XCTAssertEqual(schedule.lightsOut, lightsOut)
        XCTAssertEqual(schedule.wake, wake)
    }

    private func sampleFeatures() -> [NightFeatures] {
        var features: [NightFeatures] = []
        for day in 1...7 {
            features.append(Fixtures.makeFeatures(
                nightKey: Fixtures.date(2026, 8, day + 10, 0),
                sessionStart: Fixtures.date(2026, 8, day + 10, 23, 0),
                onset: Fixtures.date(2026, 8, day + 10, 23, 0),
                offset: Fixtures.date(2026, 8, day + 11, 7, 0),
                tstMinutes: 430,
                deepPercent: 18,
                remPercent: 22,
                deepCentroidMinutes: 130
            ))
        }
        return features
    }
}
