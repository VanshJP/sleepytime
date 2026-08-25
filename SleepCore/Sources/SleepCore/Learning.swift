import Foundation

public struct LearningTrialNight: Codable, Sendable, Equatable {
    public let nightKey: Date
    public let depthC: Double
    public let adherent: Bool
    public let deepPercent: Double?
    public let remPercent: Double?
    public let sePercent: Double?

    public init(nightKey: Date, depthC: Double, adherent: Bool, deepPercent: Double?, remPercent: Double?, sePercent: Double?) {
        self.nightKey = nightKey
        self.depthC = depthC
        self.adherent = adherent
        self.deepPercent = deepPercent
        self.remPercent = remPercent
        self.sePercent = sePercent
    }
}

public struct LearningState: Codable, Sendable, Equatable {
    public var candidateC: Double
    public var lastStepC: Double
    public var nights: [LearningTrialNight]
    public var completedTrials: Int

    public init(
        candidateC: Double = 3.0,
        lastStepC: Double = 0,
        nights: [LearningTrialNight] = [],
        completedTrials: Int = 0
    ) {
        self.candidateC = candidateC
        self.lastStepC = lastStepC
        self.nights = nights
        self.completedTrials = completedTrials
    }
}

public enum AdaptiveLearning {

    public static let stepC = 0.25
    public static let minDepthC = 2.0
    public static let maxDepthC = 4.0
    public static let trialLength = 5
    public static let adherenceOnsetToleranceMinutes: Double = 45
    public static let minimumAdherentTSTMinutes: Double = 300
    public static let successThresholdPercentagePoints = 0.8

    public static func record(
        _ state: LearningState,
        night: NightFeatures,
        schedule: ThermalSchedule,
        calendar: Calendar = .current
    ) -> LearningState {
        var next = state
        guard !state.nights.contains(where: { $0.nightKey == night.nightKey }) else { return next }

        let onsetMinute = ProfileBuilder.minutesFromNoon(night.onset, calendar: calendar)
        let targetMinute = ProfileBuilder.minutesFromNoon(schedule.lightsOut, calendar: calendar)
        var delta = abs(onsetMinute - targetMinute)
        if delta > 720 { delta = 1440 - delta }
        let adherent = delta <= adherenceOnsetToleranceMinutes
            && night.tstMinutes >= minimumAdherentTSTMinutes

        next.nights.append(LearningTrialNight(
            nightKey: night.nightKey,
            depthC: state.candidateC,
            adherent: adherent,
            deepPercent: night.hasStageDetail ? night.deepPercent : nil,
            remPercent: night.hasStageDetail ? night.remPercent : nil,
            sePercent: night.sePercent
        ))
        if next.nights.count > 60 {
            next.nights.removeFirst(next.nights.count - 60)
        }
        return next
    }

    public static func evaluate(
        _ state: LearningState,
        baselineDeepPercent: Double?,
        baselineRemPercent: Double?
    ) -> LearningState {
        guard let baselineDeep = baselineDeepPercent else { return state }

        let trial = state.nights.suffix(trialLength)
        guard trial.count == trialLength,
              trial.allSatisfy(\.adherent),
              let deeps = values(trial.map(\.deepPercent)) else { return state }

        let meanDeep = deeps.reduce(0, +) / Double(deeps.count)
        let delta = meanDeep - baselineDeep

        var next = state
        if delta > successThresholdPercentagePoints {
            let step = state.lastStepC == 0 ? stepC : state.lastStepC
            next.candidateC = clamp(state.candidateC + step)
            next.lastStepC = step
            next.completedTrials += 1
        } else if delta < -successThresholdPercentagePoints {
            let previousStep = state.lastStepC == 0 ? stepC : state.lastStepC
            let step = -previousStep
            next.candidateC = clamp(state.candidateC + step)
            next.lastStepC = step
            next.completedTrials += 1
        }
        next.nights.removeAll()
        return next
    }

    public static func effectiveDepthC(_ state: LearningState) -> Double {
        clamp(state.candidateC)
    }

    static func values(_ optionalValues: [Double?]) -> [Double]? {
        let present = optionalValues.compactMap { $0 }
        guard present.count == optionalValues.count, !present.isEmpty else { return nil }
        return present
    }

    static func clamp(_ value: Double) -> Double {
        min(maxDepthC, max(minDepthC, value))
    }
}
