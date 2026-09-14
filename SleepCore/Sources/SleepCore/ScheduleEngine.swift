import Foundation

public enum DeviceKind: String, Sendable, Codable, CaseIterable {
    case eightSleep
    case waterPad
    case airConditioner
    case generic

    public var supportsHeating: Bool {
        switch self {
        case .airConditioner: return false
        default: return true
        }
    }

    public var minCelsius: Double? {
        switch self {
        case .eightSleep, .waterPad: return 13
        case .airConditioner: return nil
        case .generic: return nil
        }
    }

    public var maxCelsius: Double? {
        switch self {
        case .eightSleep, .waterPad: return 43
        case .airConditioner: return nil
        case .generic: return nil
        }
    }

    public var acDeltaLimitC: Double {
        self == .airConditioner ? 2 : 0
    }
}

public struct ThermalSettings: Sendable, Hashable, Codable {
    public var device: DeviceKind
    public var neutralC: Double
    public var roomSetpointC: Double
    public var thermalBias: Double
    public var wakeWarmthEnabled: Bool
    public var hotSleeperMode: Bool
    public var isBiologicalSexFemale: Bool?
    public var adaptiveCoolDepthC: Double?
    /// When true, export/automation setpoints step ~1.4 °C (~2.5 °F) for manual pad controllers.
    public var gradualTransitions: Bool

    public init(
        device: DeviceKind = .eightSleep,
        neutralC: Double = 26,
        roomSetpointC: Double = 20,
        thermalBias: Double = 0,
        wakeWarmthEnabled: Bool = true,
        hotSleeperMode: Bool = false,
        isBiologicalSexFemale: Bool? = nil,
        adaptiveCoolDepthC: Double? = nil,
        gradualTransitions: Bool = false
    ) {
        self.device = device
        self.neutralC = neutralC
        self.roomSetpointC = roomSetpointC
        self.thermalBias = max(-1, min(1, thermalBias))
        self.wakeWarmthEnabled = wakeWarmthEnabled
        self.hotSleeperMode = hotSleeperMode
        self.isBiologicalSexFemale = isBiologicalSexFemale
        self.adaptiveCoolDepthC = adaptiveCoolDepthC
        self.gradualTransitions = gradualTransitions
    }

    enum CodingKeys: String, CodingKey {
        case device, neutralC, roomSetpointC, thermalBias, wakeWarmthEnabled
        case hotSleeperMode, isBiologicalSexFemale, adaptiveCoolDepthC, gradualTransitions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = try c.decodeIfPresent(DeviceKind.self, forKey: .device) ?? .eightSleep
        neutralC = try c.decodeIfPresent(Double.self, forKey: .neutralC) ?? 26
        roomSetpointC = try c.decodeIfPresent(Double.self, forKey: .roomSetpointC) ?? 20
        thermalBias = try c.decodeIfPresent(Double.self, forKey: .thermalBias) ?? 0
        wakeWarmthEnabled = try c.decodeIfPresent(Bool.self, forKey: .wakeWarmthEnabled) ?? true
        hotSleeperMode = try c.decodeIfPresent(Bool.self, forKey: .hotSleeperMode) ?? false
        isBiologicalSexFemale = try c.decodeIfPresent(Bool.self, forKey: .isBiologicalSexFemale)
        adaptiveCoolDepthC = try c.decodeIfPresent(Double.self, forKey: .adaptiveCoolDepthC)
        gradualTransitions = try c.decodeIfPresent(Bool.self, forKey: .gradualTransitions) ?? false
        thermalBias = max(-1, min(1, thermalBias))
    }
}

public struct ThermalPhase: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let rationale: String
    public let evidence: String
    public let start: Date
    public let end: Date
    public let startOffsetC: Double
    public let endOffsetC: Double

    public func offset(at date: Date) -> Double {
        guard end > start else { return endOffsetC }
        let t = max(0, min(1, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
        return startOffsetC + (endOffsetC - startOffsetC) * t
    }
}

public struct ThermalSetpoint: Sendable, Hashable, Codable {
    public let date: Date
    public let offsetC: Double

    public init(date: Date, offsetC: Double) {
        self.date = date
        self.offsetC = offsetC
    }
}

public struct MetricsSnapshot: Sendable, Hashable, Codable {
    public let sri: Double?
    public let consistencyClass: ConsistencyClass
    public let recentDeepPercent: Double?
    public let recentRemPercent: Double?
    public let recentSEPercent: Double?
    public let recentSOLMinutes: Double?
    public let recentTSTHours: Double?
    public let deepCentroidMinutesUsed: Double?
    public let nightsAnalyzed: Int
    public let confidence: Double
    public let goodNightsUsed: Int
    public let remFloorFraction: Double

    public init(
        sri: Double?,
        consistencyClass: ConsistencyClass,
        recentDeepPercent: Double?,
        recentRemPercent: Double?,
        recentSEPercent: Double?,
        recentSOLMinutes: Double?,
        recentTSTHours: Double?,
        deepCentroidMinutesUsed: Double?,
        nightsAnalyzed: Int,
        confidence: Double = 0.2,
        goodNightsUsed: Int = 0,
        remFloorFraction: Double = 0.7
    ) {
        self.sri = sri
        self.consistencyClass = consistencyClass
        self.recentDeepPercent = recentDeepPercent
        self.recentRemPercent = recentRemPercent
        self.recentSEPercent = recentSEPercent
        self.recentSOLMinutes = recentSOLMinutes
        self.recentTSTHours = recentTSTHours
        self.deepCentroidMinutesUsed = deepCentroidMinutesUsed
        self.nightsAnalyzed = nightsAnalyzed
        self.confidence = confidence
        self.goodNightsUsed = goodNightsUsed
        self.remFloorFraction = remFloorFraction
    }

    enum CodingKeys: String, CodingKey {
        case sri, consistencyClass, recentDeepPercent, recentRemPercent, recentSEPercent
        case recentSOLMinutes, recentTSTHours, deepCentroidMinutesUsed, nightsAnalyzed
        case confidence, goodNightsUsed, remFloorFraction
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sri = try c.decodeIfPresent(Double.self, forKey: .sri)
        consistencyClass = try c.decodeIfPresent(ConsistencyClass.self, forKey: .consistencyClass) ?? .moderate
        recentDeepPercent = try c.decodeIfPresent(Double.self, forKey: .recentDeepPercent)
        recentRemPercent = try c.decodeIfPresent(Double.self, forKey: .recentRemPercent)
        recentSEPercent = try c.decodeIfPresent(Double.self, forKey: .recentSEPercent)
        recentSOLMinutes = try c.decodeIfPresent(Double.self, forKey: .recentSOLMinutes)
        recentTSTHours = try c.decodeIfPresent(Double.self, forKey: .recentTSTHours)
        deepCentroidMinutesUsed = try c.decodeIfPresent(Double.self, forKey: .deepCentroidMinutesUsed)
        nightsAnalyzed = try c.decodeIfPresent(Int.self, forKey: .nightsAnalyzed) ?? 0
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.2
        goodNightsUsed = try c.decodeIfPresent(Int.self, forKey: .goodNightsUsed) ?? 0
        remFloorFraction = try c.decodeIfPresent(Double.self, forKey: .remFloorFraction) ?? 0.7
    }
}

public struct ThermalSchedule: Sendable, Hashable, Codable {
    public let lightsOut: Date
    public let wake: Date
    public let phases: [ThermalPhase]
    public let setpoints: [ThermalSetpoint]
    public let metrics: MetricsSnapshot
    public let notes: [String]

    public func offset(at date: Date) -> Double {
        for phase in phases where date >= phase.start && date < phase.end {
            return phase.offset(at: date)
        }
        if let last = phases.last, date >= last.end { return last.endOffsetC }
        if let first = phases.first, date <= first.start { return first.startOffsetC }
        return 0
    }
}

public enum ScheduleEngine {

    public static let defaultCoolDepthC = 3.0
    public static let minCoolDepthC = 2.0
    public static let maxCoolDepthC = 4.0
    public static let windDownWarmthC = 1.5
    /// Kim 2025: stay cool through REM at ~70% of the deep drop — not near-neutral.
    public static let remFloorFraction = 0.7
    public static let wakeRampTopC = 1.0
    public static let biasScaleC = 1.5

    public static func generate(
        profile: HistoryProfile,
        settings: ThermalSettings,
        anchorDay: Date,
        targetLightsOut: Date? = nil,
        targetWake: Date? = nil,
        calendar: Calendar = .current
    ) -> ThermalSchedule {
        var notes: [String] = []

        let lightsOut: Date
        if let targetLightsOut {
            lightsOut = roundTo5(targetLightsOut)
        } else if let minute = profile.medianOnsetMinuteFromNoon {
            lightsOut = roundTo5(ProfileBuilder.date(fromNoonMinute: max(0, minute - 15), on: anchorDay, calendar: calendar))
            if profile.goodNightsUsed >= 3 {
                notes.append("Bedtime anchored to your median onset across \(profile.goodNightsUsed) high-efficiency nights.")
            } else {
                notes.append("Bedtime anchored to your median sleep onset over recent nights.")
            }
        } else {
            lightsOut = roundTo5(ProfileBuilder.date(fromNoonMinute: 645, on: anchorDay, calendar: calendar))
            notes.append("No sleep history yet, so using a canonical 10:45 PM bedtime. Schedule will personalize as data arrives.")
        }

        let wake: Date
        if let targetWake {
            wake = roundTo5(targetWake)
        } else if let minute = profile.medianOffsetMinuteFromNoon {
            wake = roundTo5(ProfileBuilder.date(fromNoonMinute: minute, on: anchorDay, calendar: calendar))
        } else {
            wake = roundTo5(ProfileBuilder.date(fromNoonMinute: 1125, on: anchorDay, calendar: calendar))
        }

        let resolvedWake = wake > lightsOut ? wake : wake.addingTimeInterval(24 * 3600)

        let femalePrior = settings.isBiologicalSexFemale == true

        var coolDepth = settings.adaptiveCoolDepthC.map { min(Self.maxCoolDepthC, max(Self.minCoolDepthC, $0)) }
            ?? Self.defaultCoolDepthC
        var plateauExtraMinutes = 0.0
        var windDownMinutes = 90.0
        var rampMinutes = 45.0
        var softenRemFloor = false
        let warmWindDown = Self.windDownWarmthC + (femalePrior ? 0.5 : 0)
        var centroidMinutes: Double? = profile.recentNights.compactMap(\.deepCentroidMinutes).median

        let allowPersonalization = profile.consistencyClass != .low && !profile.recentNights.isEmpty

        if profile.consistencyClass == .low {
            notes.append("Low schedule regularity detected (SRI \(Int(profile.sri ?? 0))). Stage timing shifts night to night, so the canonical temperature template is being used. Fixing a consistent bedtime first will unlock deeper personalization.")
            centroidMinutes = nil
        }

        if allowPersonalization {
            let solMean = profile.recentSOL.mean
            if solMean > 25 {
                windDownMinutes = 120
                rampMinutes = 60
                notes.append("You take over 25 minutes to fall asleep on average, so the pre-bed warmth window was extended to 2 hours and the cooldown made more gradual.")
            }

            if let baseline = nonEmptyBaseline(profile.baselineDeep),
               profile.recentDeep.count >= 3,
               profile.recentDeep.mean < baseline.mean - 0.5 * baseline.sd {
                coolDepth = min(Self.maxCoolDepthC, coolDepth + 0.5)
                plateauExtraMinutes = min(20, plateauExtraMinutes + 20)
                notes.append("Your deep-sleep share has dipped below your own baseline, so tonight's cool plateau is slightly deeper and longer.")
            }

            let earlyAwakeningNights = profile.recentNights.filter { features in
                features.awakenings.contains { cluster in
                    cluster.startOffsetMinutes >= 45 && cluster.startOffsetMinutes <= 300
                }
            }.count
            if earlyAwakeningNights >= 2 {
                coolDepth = max(Self.minCoolDepthC, coolDepth - 0.5)
                notes.append("Recent awakenings during the early-night cooling window, so the plateau was eased to avoid overshooting.")
            }

            if let baseline = nonEmptyBaseline(profile.baselineRem),
               profile.recentRem.count >= 3,
               profile.recentRem.mean < baseline.mean - 0.5 * baseline.sd {
                softenRemFloor = true
                notes.append("REM share below your usual, so late-night cooling eases toward neutral to protect REM, which cannot thermoregulate.")
            }
        }

        if let lastTST = profile.lastNightTSTMinutes, lastTST < 390, allowPersonalization {
            coolDepth = min(Self.maxCoolDepthC, coolDepth + 0.25)
            plateauExtraMinutes = min(30, plateauExtraMinutes + 15)
            notes.append("Short sleep last night (\(Int(lastTST / 60))h \(Int(lastTST.truncatingRemainder(dividingBy: 60)))m), so slow-wave pressure is elevated, so tonight's cool plateau runs slightly deeper and longer.")
        }

        if profile.timezoneShiftDetected {
            notes.append("Travel detected: anchors follow your most recent local schedule and shift gradually as your rhythm settles.")
        }

        if femalePrior {
            coolDepth = max(1.5, coolDepth - 1.0)
            notes.append("Starting from a slightly warmer template (research suggests women prefer ~1–2 °C warmer bed microclimates).")
        }

        let biasShift = settings.thermalBias * Self.biasScaleC
        if settings.thermalBias != 0 {
            notes.append(settings.thermalBias > 0
                ? "Warmer-biased by your preference."
                : "Cooler-biased by your preference.")
        }

        // Kim 2025: stay cool through REM at ~70% of peak cool depth (not near-neutral).
        var remFloor = -coolDepth * Self.remFloorFraction
        if softenRemFloor {
            remFloor = min(0, remFloor * 0.35)
        } else {
            notes.append("REM hold stays cool (~\(Int(Self.remFloorFraction * 100))% of peak cool depth) — controlled data favor cool beds through REM, not warming.")
        }

        let cycles: [SleepCycle] = {
            guard let asleep = profile.medianAsleepMinutes ?? (profile.recentTST.count > 0 ? profile.recentTST.mean : nil),
                  let deep = profile.medianDeepMinutes,
                  let rem = profile.medianRemMinutes else { return [] }
            return CycleArchitecture.build(asleepMinutes: asleep, deepMinutes: deep, remMinutes: rem)
        }()

        let swsEnd: Date = {
            let minutes: Double
            if let period = profile.recentCyclePeriodMinutes, period >= 70, period <= 120 {
                minutes = min(300, max(120, period * 2.2)) + plateauExtraMinutes
            } else if let centroid = centroidMinutes, centroid > 30 {
                minutes = min(300, max(120, centroid * 1.6)) + plateauExtraMinutes
            } else if let cycleEnd = CycleArchitecture.deepWindowEndMinutes(cycles: cycles) {
                minutes = min(300, max(120, cycleEnd)) + plateauExtraMinutes
                notes.append("Deep plateau ends with your reconstructed ultradian deep window (\(Int(cycleEnd)) min after lights-out).")
            } else {
                minutes = 210 + plateauExtraMinutes
            }
            return min(lightsOut.addingTimeInterval(minutes * 60), resolvedWake.addingTimeInterval(-45 * 60))
        }()

        var descentEnd = lightsOut.addingTimeInterval(rampMinutes * 60)
        descentEnd = max(min(descentEnd, swsEnd), lightsOut.addingTimeInterval(60))
        let plateauStart = descentEnd
        let clampedSwsEnd = max(swsEnd, descentEnd)
        let plateauTemp = -coolDepth + biasShift
        let windDownStart = lightsOut.addingTimeInterval(-windDownMinutes * 60)
        let windDownTemp = settings.device.supportsHeating ? warmWindDown + biasShift : biasShift

        let useWakeRamp = settings.wakeWarmthEnabled && !settings.hotSleeperMode
        let tminOffsetHours: Double = {
            switch settings.isBiologicalSexFemale {
            case .some(true): return 3.5
            case .some(false): return 2.0
            case .none: return 2.75
            }
        }()
        let predictedTmin = resolvedWake.addingTimeInterval(-tminOffsetHours * 3600)
        var rampStart = max(resolvedWake.addingTimeInterval(-45 * 60), predictedTmin)
        if rampStart >= resolvedWake.addingTimeInterval(-10 * 60) {
            rampStart = resolvedWake.addingTimeInterval(-10 * 60)
        }
        let wakeTop: Double = useWakeRamp ? Self.wakeRampTopC + biasShift : remFloor + biasShift
        if settings.hotSleeperMode {
            notes.append("Hot-sleeper mode: no pre-wake warming.")
        } else if !settings.wakeWarmthEnabled {
            notes.append("Pre-wake warming disabled.")
        }

        var phases: [ThermalPhase] = []

        if settings.device.supportsHeating {
            phases.append(ThermalPhase(
                id: "winddown",
                name: "Wind-Down Warmth",
                rationale: "Peripheral warmth opens distal blood vessels, shunting core heat outward and accelerating the core-temperature drop that initiates sleep.",
                evidence: "Kräuchi 2000 AJP · Haghayegh 2019 Sleep Med Rev",
                start: windDownStart,
                end: lightsOut,
                startOffsetC: windDownTemp,
                endOffsetC: windDownTemp
            ))
        }

        phases.append(ThermalPhase(
            id: "descent",
            name: "Core Descent",
            rationale: "Heat is removed right at lights-out so your core temperature falls steeply through the first cycle. The steepest decline supports the deepest sleep.",
            evidence: "Campbell & Broughton 1994 Chronobiol Int · Okamoto-Mizuno 2012 J Physiol Anthropol",
            start: lightsOut,
            end: descentEnd,
            startOffsetC: windDownTemp,
            endOffsetC: plateauTemp
        ))

        let remHoldEnd = max(rampStart, clampedSwsEnd)
        let remHoldExists = remHoldEnd.timeIntervalSince(clampedSwsEnd) > 60
        let plateauEnd = remHoldExists ? clampedSwsEnd : remHoldEnd

        phases.append(ThermalPhase(
            id: "plateau",
            name: "Deep-Sleep Plateau",
            rationale: "A sustained cool plateau through cycles 1–2 maximizes conductive heat loss when slow-wave sleep concentrates; pulses do not work, duration does.",
            evidence: "Herberger 2024 Sci Rep (+7.5 min N3) · Moyen 2024 Bioengineering",
            start: plateauStart,
            end: plateauEnd,
            startOffsetC: plateauTemp,
            endOffsetC: plateauTemp
        ))

        if remHoldExists {
            phases.append(ThermalPhase(
                id: "remhold",
                name: "REM Cool Hold",
                rationale: "REM cannot thermoregulate well, so the bed stays cool — about 70% of the deep-night drop — rather than warming. A 2025 PSG crossover found more REM and faster REM onset when the bed stayed cool through REM.",
                evidence: "Kim 2025 Healthcare · Cerri 2017 Front Physiol",
                start: clampedSwsEnd,
                end: remHoldEnd,
                startOffsetC: plateauTemp,
                endOffsetC: remFloor + biasShift
            ))
        }

        if useWakeRamp {
            phases.append(ThermalPhase(
                id: "wakeramp",
                name: "Wake Ramp",
                rationale: "A gentle final warmth rides the natural morning rise in body temperature to soften waking, extrapolated from dawn-simulation physiology.",
                evidence: "Kräuchi 2004 J Sleep Res · Kim 2025 Healthcare (pre-wake warm)",
                start: remHoldEnd,
                end: resolvedWake,
                startOffsetC: remFloor + biasShift,
                endOffsetC: wakeTop
            ))
        } else {
            phases.append(ThermalPhase(
                id: "holdtowake",
                name: "Steady Hold",
                rationale: "Holding stable through the morning hours avoids disturbing REM-dominant sleep before your alarm.",
                evidence: "Cerri 2017 Front Physiol",
                start: remHoldEnd,
                end: resolvedWake,
                startOffsetC: remFloor + biasShift,
                endOffsetC: remFloor + biasShift
            ))
        }

        let confidence = ScheduleConfidence.score(profile: profile, goodNightsUsed: profile.goodNightsUsed)

        let metrics = MetricsSnapshot(
            sri: profile.sri,
            consistencyClass: profile.consistencyClass,
            recentDeepPercent: profile.recentDeep.count > 0 ? profile.recentDeep.mean : nil,
            recentRemPercent: profile.recentRem.count > 0 ? profile.recentRem.mean : nil,
            recentSEPercent: profile.recentSE.count > 0 ? profile.recentSE.mean : nil,
            recentSOLMinutes: profile.recentSOL.count > 0 ? profile.recentSOL.mean : nil,
            recentTSTHours: profile.recentTST.count > 0 ? profile.recentTST.mean / 60 : nil,
            deepCentroidMinutesUsed: centroidMinutes,
            nightsAnalyzed: profile.recentNights.count,
            confidence: confidence,
            goodNightsUsed: profile.goodNightsUsed,
            remFloorFraction: Self.remFloorFraction
        )

        let setpoints = sampleSetpoints(
            phases: phases,
            from: windDownStart,
            to: resolvedWake,
            gradual: settings.gradualTransitions
        )

        return ThermalSchedule(
            lightsOut: lightsOut,
            wake: resolvedWake,
            phases: phases,
            setpoints: setpoints,
            metrics: metrics,
            notes: notes
        )
    }

    static func nonEmptyBaseline(_ stats: StageStats) -> StageStats? {
        stats.count > 0 ? stats : nil
    }

    static func sampleSetpoints(
        phases: [ThermalPhase],
        from start: Date,
        to end: Date,
        gradual: Bool = false
    ) -> [ThermalSetpoint] {
        if gradual {
            return gradualSetpoints(phases: phases, from: start, to: end)
        }
        var times: Set<TimeInterval> = []
        let gridSeconds = 30.0 * 60
        var cursor = start.timeIntervalSince1970
        let ceilToGrid = { (t: TimeInterval) -> TimeInterval in
            let r = t.truncatingRemainder(dividingBy: gridSeconds)
            return r == 0 ? t : t + gridSeconds - r
        }
        cursor = ceilToGrid(cursor)
        while cursor <= end.timeIntervalSince1970 {
            times.insert(cursor)
            cursor += gridSeconds
        }
        for phase in phases {
            times.insert(phase.start.timeIntervalSince1970)
            times.insert(phase.end.timeIntervalSince1970)
        }
        return times.sorted().map { tick in
            let date = Date(timeIntervalSince1970: tick)
            return ThermalSetpoint(date: date, offsetC: offsetIn(phases: phases, at: date))
        }
    }

    /// ~1.4 °C (~2.5 °F) steps for manual ChiliPad-style controllers.
    static func gradualSetpoints(phases: [ThermalPhase], from start: Date, to end: Date) -> [ThermalSetpoint] {
        let stepC = 1.4
        var points: [ThermalSetpoint] = []
        var previousOffset: Double?
        for phase in phases {
            let startOff = phase.startOffsetC
            let endOff = phase.endOffsetC
            if previousOffset == nil || abs((previousOffset ?? 0) - startOff) > 0.05 {
                points.append(ThermalSetpoint(date: phase.start, offsetC: startOff))
                previousOffset = startOff
            }
            let delta = endOff - startOff
            let steps = max(1, Int((abs(delta) / stepC).rounded()))
            if steps > 1, phase.end > phase.start {
                let duration = phase.end.timeIntervalSince(phase.start)
                for i in 1...steps {
                    let t = Double(i) / Double(steps)
                    let date = phase.start.addingTimeInterval(duration * t)
                    let offset = startOff + delta * t
                    if abs(offset - (previousOffset ?? offset)) >= stepC * 0.45 || i == steps {
                        points.append(ThermalSetpoint(date: date, offsetC: offset))
                        previousOffset = offset
                    }
                }
            } else if abs(endOff - startOff) > 0.05 {
                points.append(ThermalSetpoint(date: phase.end, offsetC: endOff))
                previousOffset = endOff
            }
        }
        if points.last?.date != end {
            points.append(ThermalSetpoint(date: end, offsetC: offsetIn(phases: phases, at: end)))
        }
        // Deduplicate near-identical consecutive times
        var deduped: [ThermalSetpoint] = []
        for point in points {
            if let last = deduped.last,
               abs(last.date.timeIntervalSince(point.date)) < 30,
               abs(last.offsetC - point.offsetC) < 0.05 {
                continue
            }
            deduped.append(point)
        }
        _ = start
        return deduped
    }

    static func offsetIn(phases: [ThermalPhase], at date: Date) -> Double {
        for phase in phases where date >= phase.start && date < phase.end {
            return phase.offset(at: date)
        }
        if let last = phases.last, date >= last.end { return last.endOffsetC }
        if let first = phases.first { return first.startOffsetC }
        return 0
    }

    static func roundTo5(_ date: Date) -> Date {
        let interval = date.timeIntervalSinceReferenceDate
        let rounded = (interval / 300).rounded() * 300
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}

extension Array where Element == Double {
    var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = sorted()
        let mid = count / 2
        return count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}
