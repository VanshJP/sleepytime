import Foundation

public enum ProfileBuilder {

    /// Sleep efficiency gate for "good night" timing medians (Sleep Optimizer).
    public static let goodNightSEThreshold = 85.0

    public static func profile(
        features: [NightFeatures],
        timelines: [NightTimeline],
        calendar: Calendar = .current,
        recentWindow: Int = 7,
        baselineWindow: Int = 21,
        minBaselineNights: Int = 5
    ) -> HistoryProfile {
        let usable = features
            .filter { $0.isUsableNight }
            .sorted { $0.nightKey < $1.nightKey }

        let detailed = usable.filter { $0.hasStageDetail }
        let recentDetailed = Array(detailed.suffix(recentWindow))
        let priorDetailed = Array(detailed.dropLast(recentWindow).suffix(baselineWindow))

        // Prefer high-efficiency nights for timing + stage medians when enough exist.
        let goodNights = selectGoodNights(from: recentDetailed)
        let timingSource = goodNights.count >= 3 ? goodNights : recentDetailed

        let sriValue = Regularity.sri(nights: timelines, calendar: calendar)

        let cyclePeriods = recentDetailed.compactMap(\.cyclePeriodMinutes)
        let recentCyclePeriod: Double? = cyclePeriods.isEmpty ? nil : median(cyclePeriods)

        let lastTST = usable.last?.tstMinutes

        let tzIDs = recentDetailed.compactMap(\.timeZoneIdentifier)
        var tzCounts: [String: Int] = [:]
        for id in tzIDs { tzCounts[id, default: 0] += 1 }
        let dominantTZ = tzIDs.isEmpty ? nil : tzCounts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }?.key
        let tzShift = Set(tzIDs).count > 1

        var medianCalendar = calendar
        if let id = dominantTZ, let tz = TimeZone(identifier: id) {
            medianCalendar.timeZone = tz
        }

        let medianDeepMins: Double? = timingSource.isEmpty ? nil : median(timingSource.map(\.deepMinutes))
        let medianRemMins: Double? = timingSource.isEmpty ? nil : median(timingSource.map(\.remMinutes))
        let medianAsleep: Double? = timingSource.isEmpty ? nil : median(timingSource.map(\.tstMinutes))

        return HistoryProfile(
            recentNights: recentDetailed,
            recentDeep: stageStats(recentDetailed.map { $0.deepPercent }),
            recentRem: stageStats(recentDetailed.map { $0.remPercent }),
            recentSE: stageStats(recentDetailed.map { $0.sePercent }),
            recentSOL: stageStats(recentDetailed.map { $0.solMinutes }),
            recentTST: stageStats(recentDetailed.map { $0.tstMinutes }),
            baselineDeep: baselineStats(priorDetailed.map { $0.deepPercent }, minimumCount: minBaselineNights),
            baselineRem: baselineStats(priorDetailed.map { $0.remPercent }, minimumCount: minBaselineNights),
            medianOnsetMinuteFromNoon: medianMinuteFromNoon(timingSource.map { $0.onset }, calendar: medianCalendar),
            medianOffsetMinuteFromNoon: medianMinuteFromNoon(timingSource.map { $0.offset }, calendar: medianCalendar),
            sri: sriValue,
            consistencyClass: ConsistencyClass.classify(sri: sriValue),
            recentCyclePeriodMinutes: recentCyclePeriod,
            lastNightTSTMinutes: lastTST,
            dominantTimeZoneID: dominantTZ,
            timezoneShiftDetected: tzShift,
            goodNightsUsed: goodNights.count,
            medianAsleepMinutes: medianAsleep,
            medianDeepMinutes: medianDeepMins,
            medianRemMinutes: medianRemMins
        )
    }

    /// Good nights: SE ≥ 85. If fewer than 3, take the top half by SE (min 3 when possible).
    static func selectGoodNights(from nights: [NightFeatures]) -> [NightFeatures] {
        let high = nights.filter { $0.sePercent >= goodNightSEThreshold }
        if high.count >= 3 { return high }
        guard nights.count >= 3 else { return high }
        let ranked = nights.sorted { $0.sePercent > $1.sePercent }
        let take = max(3, nights.count / 2)
        return Array(ranked.prefix(take))
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }

    public static func canonical() -> HistoryProfile {
        HistoryProfile.canonical()
    }

    public static func minutesFromNoon(_ date: Date, calendar: Calendar) -> Double {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return Double(((hour * 60 + minute) - 720 + 1440) % 1440)
    }

    public static func date(fromNoonMinute minute: Double, on day: Date, calendar: Calendar) -> Date {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        return noon.addingTimeInterval(minute * 60)
    }

    static func medianMinuteFromNoon(_ dates: [Date], calendar: Calendar) -> Double? {
        guard !dates.isEmpty else { return nil }
        let values = dates.map { minutesFromNoon($0, calendar: calendar) }.sorted()
        let mid = values.count / 2
        if values.count % 2 == 1 { return values[mid] }
        return meanCircular(values[mid - 1], values[mid])
    }

    static func meanCircular(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b)
        if diff <= 720 { return (a + b) / 2 }
        let wrapMean = ((a + b) / 2 + 720).truncatingRemainder(dividingBy: 1440)
        return wrapMean
    }

    static func stageStats(_ values: [Double]) -> StageStats {
        guard !values.isEmpty else { return .empty }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return StageStats(mean: mean, sd: variance.squareRoot(), count: values.count)
    }

    static func baselineStats(_ values: [Double], minimumCount: Int) -> StageStats {
        values.count >= minimumCount ? stageStats(values) : .empty
    }
}
