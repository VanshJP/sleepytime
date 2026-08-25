import Foundation

public enum SleepStage: String, Sendable, Codable, CaseIterable, Hashable {
    case awake
    case core
    case deep
    case rem
    case unspecified

    public var isAsleep: Bool { self != .awake }
}

public struct SleepSegment: Sendable, Hashable, Codable {
    public let start: Date
    public let end: Date
    public let stage: SleepStage

    public init(start: Date, end: Date, stage: SleepStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

public struct TaggedSegment: Sendable, Hashable {
    public let sourceID: String
    public let segment: SleepSegment
    public let timeZoneIdentifier: String?

    public init(sourceID: String, segment: SleepSegment, timeZoneIdentifier: String? = nil) {
        self.sourceID = sourceID
        self.segment = segment
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public struct NightTimeline: Sendable, Hashable, Codable {
    public let nightKey: Date
    public let segments: [SleepSegment]
    public let timeZoneIdentifier: String?

    public init(nightKey: Date, segments: [SleepSegment], timeZoneIdentifier: String? = nil) {
        self.nightKey = nightKey
        self.segments = segments.sorted { $0.start < $1.start }
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public struct AwakeningCluster: Sendable, Hashable, Codable {
    public let startOffsetMinutes: Double
    public let endOffsetMinutes: Double
    public let durationMinutes: Double
}

public struct NightFeatures: Sendable, Hashable, Codable {
    public let nightKey: Date
    public let sessionStart: Date
    public let onset: Date
    public let offset: Date
    public let tstMinutes: Double
    public let tibMinutes: Double
    public let sePercent: Double
    public let solMinutes: Double
    public let wasoMinutes: Double
    public let deepMinutes: Double
    public let remMinutes: Double
    public let coreMinutes: Double
    public let unspecifiedMinutes: Double
    public let deepPercent: Double
    public let remPercent: Double
    public let remLatencyMinutes: Double?
    public let deepCentroidMinutes: Double?
    public let deepFrontRatio: Double?
    public let midsleep: Date
    public let awakenings: [AwakeningCluster]
    public let hasStageDetail: Bool
    public let cyclePeriodMinutes: Double?
    public let timeZoneIdentifier: String?

    public init(
        nightKey: Date,
        sessionStart: Date,
        onset: Date,
        offset: Date,
        tstMinutes: Double,
        tibMinutes: Double,
        sePercent: Double,
        solMinutes: Double,
        wasoMinutes: Double,
        deepMinutes: Double,
        remMinutes: Double,
        coreMinutes: Double,
        unspecifiedMinutes: Double,
        deepPercent: Double,
        remPercent: Double,
        remLatencyMinutes: Double? = nil,
        deepCentroidMinutes: Double? = nil,
        deepFrontRatio: Double? = nil,
        midsleep: Date,
        awakenings: [AwakeningCluster] = [],
        hasStageDetail: Bool,
        cyclePeriodMinutes: Double? = nil,
        timeZoneIdentifier: String? = nil
    ) {
        self.nightKey = nightKey
        self.sessionStart = sessionStart
        self.onset = onset
        self.offset = offset
        self.tstMinutes = tstMinutes
        self.tibMinutes = tibMinutes
        self.sePercent = sePercent
        self.solMinutes = solMinutes
        self.wasoMinutes = wasoMinutes
        self.deepMinutes = deepMinutes
        self.remMinutes = remMinutes
        self.coreMinutes = coreMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.deepPercent = deepPercent
        self.remPercent = remPercent
        self.remLatencyMinutes = remLatencyMinutes
        self.deepCentroidMinutes = deepCentroidMinutes
        self.deepFrontRatio = deepFrontRatio
        self.midsleep = midsleep
        self.awakenings = awakenings
        self.hasStageDetail = hasStageDetail
        self.cyclePeriodMinutes = cyclePeriodMinutes
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var isUsableNight: Bool { tstMinutes >= 120 }
}

public struct StageStats: Sendable, Hashable, Codable {
    public let mean: Double
    public let sd: Double
    public let count: Int

    public static let empty = StageStats(mean: 0, sd: 0, count: 0)
}

public struct HistoryProfile: Sendable, Hashable, Codable {
    public let recentNights: [NightFeatures]
    public let recentDeep: StageStats
    public let recentRem: StageStats
    public let recentSE: StageStats
    public let recentSOL: StageStats
    public let recentTST: StageStats
    public let baselineDeep: StageStats
    public let baselineRem: StageStats
    public let medianOnsetMinuteFromNoon: Double?
    public let medianOffsetMinuteFromNoon: Double?
    public let sri: Double?
    public let consistencyClass: ConsistencyClass
    public let recentCyclePeriodMinutes: Double?
    public let lastNightTSTMinutes: Double?
    public let dominantTimeZoneID: String?
    public let timezoneShiftDetected: Bool
}

public enum ConsistencyClass: String, Sendable, Codable {
    case high
    case moderate
    case low

    public static func classify(sri: Double?) -> ConsistencyClass {
        guard let sri else { return .moderate }
        if sri >= 80 { return .high }
        if sri >= 65 { return .moderate }
        return .low
    }
}

extension HistoryProfile {
    public static func canonical() -> HistoryProfile {
        HistoryProfile(
            recentNights: [],
            recentDeep: .empty,
            recentRem: .empty,
            recentSE: .empty,
            recentSOL: .empty,
            recentTST: .empty,
            baselineDeep: .empty,
            baselineRem: .empty,
            medianOnsetMinuteFromNoon: nil,
            medianOffsetMinuteFromNoon: nil,
            sri: nil,
            consistencyClass: .moderate,
            recentCyclePeriodMinutes: nil,
            lastNightTSTMinutes: nil,
            dominantTimeZoneID: nil,
            timezoneShiftDetected: false
        )
    }
}
