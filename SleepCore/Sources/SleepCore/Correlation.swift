import Foundation

/// Mean commanded bed temperature (°C offset from neutral) while a given
/// sleep stage was active — the on-device audit from Sleep Optimizer.
public struct StageTempCorrelation: Sendable, Hashable, Codable {
    public let stage: SleepStage
    public let meanOffsetC: Double
    public let minutesObserved: Double
}

public struct NightThermalAudit: Sendable, Hashable, Codable {
    public let nightKey: Date
    public let correlations: [StageTempCorrelation]
    public let deepMeanOffsetC: Double?
    public let remMeanOffsetC: Double?
    public let coreMeanOffsetC: Double?
    public let awakeMeanOffsetC: Double?
    public let coolingLandedOnDeep: Bool?
    public let summary: String

    public init(
        nightKey: Date,
        correlations: [StageTempCorrelation],
        deepMeanOffsetC: Double?,
        remMeanOffsetC: Double?,
        coreMeanOffsetC: Double?,
        awakeMeanOffsetC: Double?,
        coolingLandedOnDeep: Bool?,
        summary: String
    ) {
        self.nightKey = nightKey
        self.correlations = correlations
        self.deepMeanOffsetC = deepMeanOffsetC
        self.remMeanOffsetC = remMeanOffsetC
        self.coreMeanOffsetC = coreMeanOffsetC
        self.awakeMeanOffsetC = awakeMeanOffsetC
        self.coolingLandedOnDeep = coolingLandedOnDeep
        self.summary = summary
    }
}

public enum ThermalCorrelation {

    /// Minute-integrate schedule offsets against a night's stage timeline.
    public static func audit(
        night: NightTimeline,
        features: NightFeatures,
        schedule: ThermalSchedule
    ) -> NightThermalAudit {
        var sums: [SleepStage: Double] = [:]
        var mins: [SleepStage: Double] = [:]

        for segment in night.segments where segment.duration > 0 {
            var cursor = segment.start
            let end = segment.end
            while cursor < end {
                let next = min(end, cursor.addingTimeInterval(60))
                let mid = cursor.addingTimeInterval(next.timeIntervalSince(cursor) / 2)
                // Map last night's clock onto tonight's schedule shape via onset-relative offset.
                let relative = mid.timeIntervalSince(features.onset)
                let mapped = schedule.lightsOut.addingTimeInterval(relative)
                let offset = schedule.offset(at: mapped)
                sums[segment.stage, default: 0] += offset
                mins[segment.stage, default: 0] += next.timeIntervalSince(cursor) / 60
                cursor = next
            }
        }

        let correlations: [StageTempCorrelation] = SleepStage.allCases.compactMap { stage in
            guard let minutes = mins[stage], minutes > 0, let sum = sums[stage] else { return nil }
            return StageTempCorrelation(stage: stage, meanOffsetC: sum / minutes, minutesObserved: minutes)
        }

        func mean(for stage: SleepStage) -> Double? {
            correlations.first { $0.stage == stage }?.meanOffsetC
        }

        let deep = mean(for: .deep)
        let rem = mean(for: .rem)
        let core = mean(for: .core)
        let awake = mean(for: .awake)

        let landed: Bool?
        if let deep, let rem {
            landed = deep <= rem - 0.3
        } else if let deep, let core {
            landed = deep <= core - 0.2
        } else {
            landed = nil
        }

        let summary: String
        switch landed {
        case .some(true):
            summary = "Cooling lined up with deep sleep — the coldest commanded bed temps landed while you were in deep."
        case .some(false):
            summary = "Cooling and deep sleep were misaligned last night. Tonight's anchors will retarget your deep window."
        case .none:
            summary = "Not enough staged minutes to audit cooling placement yet."
        }

        return NightThermalAudit(
            nightKey: features.nightKey,
            correlations: correlations,
            deepMeanOffsetC: deep,
            remMeanOffsetC: rem,
            coreMeanOffsetC: core,
            awakeMeanOffsetC: awake,
            coolingLandedOnDeep: landed,
            summary: summary
        )
    }
}
