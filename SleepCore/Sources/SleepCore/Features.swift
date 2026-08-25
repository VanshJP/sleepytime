import Foundation

public enum FeatureExtractor {

    public static func features(for night: NightTimeline, calendar: Calendar = .current) -> NightFeatures? {
        let segments = night.segments.filter { $0.end > $0.start }
        guard !segments.isEmpty else { return nil }

        let asleepSegments = segments.filter { $0.stage.isAsleep }
        guard !asleepSegments.isEmpty else { return nil }

        let sessionStart = segments.map(\.start).min()!
        let onset = asleepSegments.map(\.start).min()!
        let offset = asleepSegments.map(\.end).max()!

        let tstMinutes = unionedDuration(of: asleepSegments, within: onset...offset) / 60
        let awakeInside = segments.filter { $0.stage == .awake }
            .compactMap { intervalIntersection($0, onset...offset) }
        let wasoMinutes = unionedDurations(intervals: awakeInside) / 60

        let deepIntervals = asleepSegments.filter { $0.stage == .deep }
        let remIntervals = asleepSegments.filter { $0.stage == .rem }
        let coreIntervals = asleepSegments.filter { $0.stage == .core }
        let unspecifiedIntervals = asleepSegments.filter { $0.stage == .unspecified }

        let deepMinutes = unionedDurations(intervals: deepIntervals.compactMap { intervalIntersection($0, onset...offset) }) / 60
        let remMinutes = unionedDurations(intervals: remIntervals.compactMap { intervalIntersection($0, onset...offset) }) / 60
        let coreMinutes = unionedDurations(intervals: coreIntervals.compactMap { intervalIntersection($0, onset...offset) }) / 60
        let unspecifiedMinutes = unionedDurations(intervals: unspecifiedIntervals.compactMap { intervalIntersection($0, onset...offset) }) / 60

        let tibMinutes = offset.timeIntervalSince(sessionStart) / 60
        let se = tibMinutes > 0 ? (tstMinutes / tibMinutes) * 100 : 0
        let hasDetail = deepMinutes > 0 || remMinutes > 0 || coreMinutes > 0

        var clusters: [AwakeningCluster] = []
        for merged in mergeOverlapping(awakeInside) {
            let minutes = merged.duration / 60
            if minutes >= 5 {
                clusters.append(AwakeningCluster(
                    startOffsetMinutes: merged.start.timeIntervalSince(onset) / 60,
                    endOffsetMinutes: merged.end.timeIntervalSince(onset) / 60,
                    durationMinutes: minutes
                ))
            }
        }

        return NightFeatures(
            nightKey: night.nightKey,
            sessionStart: sessionStart,
            onset: onset,
            offset: offset,
            tstMinutes: tstMinutes,
            tibMinutes: tibMinutes,
            sePercent: se,
            solMinutes: max(0, onset.timeIntervalSince(sessionStart) / 60),
            wasoMinutes: wasoMinutes,
            deepMinutes: deepMinutes,
            remMinutes: remMinutes,
            coreMinutes: coreMinutes,
            unspecifiedMinutes: unspecifiedMinutes,
            deepPercent: tstMinutes > 0 ? deepMinutes / tstMinutes * 100 : 0,
            remPercent: tstMinutes > 0 ? remMinutes / tstMinutes * 100 : 0,
            remLatencyMinutes: remLatency(of: remIntervals, onset: onset),
            deepCentroidMinutes: deepCentroid(of: deepIntervals, onset: onset),
            deepFrontRatio: frontRatio(of: deepIntervals, onset: onset, offset: offset),
            midsleep: onset.addingTimeInterval(offset.timeIntervalSince(onset) / 2),
            awakenings: clusters,
            hasStageDetail: hasDetail,
            cyclePeriodMinutes: cyclePeriod(of: remIntervals, onset: onset, offset: offset),
            timeZoneIdentifier: night.timeZoneIdentifier
        )
    }

    static func cyclePeriod(of remIntervals: [SleepSegment], onset: Date, offset: Date) -> Double? {
        let starts = mergeOverlapping(remIntervals)
            .filter { $0.end > onset && $0.start < offset }
            .map { max($0.start, onset).timeIntervalSince(onset) / 60 }
            .sorted()
        guard starts.count >= 2 else { return nil }
        var gaps: [Double] = []
        for (a, b) in zip(starts, starts.dropFirst()) {
            let gap = b - a
            if gap >= 45 && gap <= 180 { gaps.append(gap) }
        }
        guard !gaps.isEmpty else { return nil }
        let sorted = gaps.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }

    static func remLatency(of remIntervals: [SleepSegment], onset: Date) -> Double? {
        guard let first = remIntervals.map(\.start).min() else { return nil }
        return first.timeIntervalSince(onset) / 60
    }

    static func deepCentroid(of deepIntervals: [SleepSegment], onset: Date) -> Double? {
        let intervals = deepIntervals.compactMap { intervalIntersection($0, onset...(onset.addingTimeInterval(24 * 3600))) }
        guard !intervals.isEmpty else { return nil }
        var weightedSum: Double = 0
        var total: Double = 0
        for interval in mergeOverlapping(intervals) {
            let mid = interval.start.addingTimeInterval(interval.duration / 2)
            let minutesFromOnset = mid.timeIntervalSince(onset) / 60
            let minutes = interval.duration / 60
            weightedSum += minutesFromOnset * minutes
            total += minutes
        }
        guard total > 0 else { return nil }
        return weightedSum / total
    }

    static func frontRatio(of deepIntervals: [SleepSegment], onset: Date, offset: Date) -> Double? {
        let totalDeep = unionedDurations(intervals: deepIntervals) 
        guard totalDeep > 0 else { return nil }
        let midpoint = onset.addingTimeInterval(offset.timeIntervalSince(onset) / 2)
        let firstHalf = deepIntervals.compactMap { intervalIntersection($0, onset...midpoint) }
        let firstHalfDeep = unionedDurations(intervals: firstHalf)
        return firstHalfDeep / totalDeep
    }

    static func intervalIntersection(_ segment: SleepSegment, _ bounds: ClosedRange<Date>) -> SleepSegment? {
        let start = max(segment.start, bounds.lowerBound)
        let end = min(segment.end, bounds.upperBound)
        guard end > start else { return nil }
        return SleepSegment(start: start, end: end, stage: segment.stage)
    }

    static func mergeOverlapping(_ segments: [SleepSegment]) -> [SleepSegment] {
        let sorted = segments.sorted { $0.start < $1.start }
        var merged: [SleepSegment] = []
        for segment in sorted {
            if var last = merged.last, segment.start <= last.end {
                if segment.end > last.end {
                    last = SleepSegment(start: last.start, end: segment.end, stage: last.stage)
                    merged[merged.count - 1] = last
                }
            } else {
                merged.append(segment)
            }
        }
        return merged
    }

    static func unionedDurations(intervals: [SleepSegment]) -> TimeInterval {
        mergeOverlapping(intervals).reduce(0) { $0 + $1.duration }
    }

    static func unionedDuration(of segments: [SleepSegment], within bounds: ClosedRange<Date>) -> TimeInterval {
        unionedDurations(intervals: segments.compactMap { intervalIntersection($0, bounds) })
    }
}
