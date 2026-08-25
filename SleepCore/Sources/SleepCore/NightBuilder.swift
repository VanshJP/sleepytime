import Foundation

public enum NightBuilder {

    struct KeyedSession {
        let nightKey: Date
        let sourceID: String
        let segments: [SleepSegment]
        let timeZoneIdentifier: String?
    }

    public static func buildNights(
        tagged: [TaggedSegment],
        preferredSources: [String] = [],
        calendar: Calendar = .current
    ) -> [NightTimeline] {
        let valid = tagged.filter { $0.segment.end > $0.segment.start }
        guard !valid.isEmpty else { return [] }

        var bySource: [String: [TaggedSegment]] = [:]
        for item in valid {
            bySource[item.sourceID, default: []].append(item)
        }

        var keyedSessions: [KeyedSession] = []
        for (source, items) in bySource {
            for session in sessions(from: items.map(\.segment)) {
                guard let start = session.map(\.start).min() else { continue }
                let tzID = items.first { $0.segment.start == start }?.timeZoneIdentifier
                    ?? items.first?.timeZoneIdentifier
                keyedSessions.append(KeyedSession(
                    nightKey: nightKey(for: start, timeZoneID: tzID, calendar: calendar),
                    sourceID: source,
                    segments: session,
                    timeZoneIdentifier: tzID
                ))
            }
        }

        var byNight: [Date: [KeyedSession]] = [:]
        for keyed in keyedSessions {
            byNight[keyed.nightKey, default: []].append(keyed)
        }

        var nights: [NightTimeline] = []
        for (key, keyed) in byNight {
            guard let winner = selectWinner(sessions: keyed, preferredSources: preferredSources) else { continue }
            let winnerSessions = keyed.filter { $0.sourceID == winner }
            let kept = winnerSessions.filter { !isNap(session: $0.segments, calendar: calendar) }
            let merged = kept.flatMap { $0.segments }
            let tz = kept.compactMap(\.timeZoneIdentifier).first
            if !merged.isEmpty {
                nights.append(NightTimeline(nightKey: key, segments: merged, timeZoneIdentifier: tz))
            }
        }
        return nights.sorted { $0.nightKey < $1.nightKey }
    }

    static func nightKey(for date: Date, timeZoneID: String?, calendar: Calendar) -> Date {
        var cal = calendar
        if let id = timeZoneID, let tz = TimeZone(identifier: id) {
            cal.timeZone = tz
        }
        let shifted = cal.date(byAdding: .hour, value: -6, to: date) ?? date
        return cal.startOfDay(for: shifted)
    }

    static func selectWinner(sessions: [KeyedSession], preferredSources: [String]) -> String? {
        var asleepMinutesBySource: [String: Double] = [:]
        for keyed in sessions {
            let minutes = keyed.segments.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.duration / 60 }
            if minutes > 0 {
                asleepMinutesBySource[keyed.sourceID, default: 0] += minutes
            }
        }
        guard !asleepMinutesBySource.isEmpty else {
            return sessions.first?.sourceID
        }
        for source in preferredSources where asleepMinutesBySource[source] != nil {
            return source
        }
        return asleepMinutesBySource.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }?.key
    }

    public static func sessions(from segments: [SleepSegment], gapTolerance: TimeInterval = 120 * 60) -> [[SleepSegment]] {
        let sorted = segments.sorted { $0.start < $1.start }
        var sessions: [[SleepSegment]] = []
        var current: [SleepSegment] = []
        var currentEnd: Date?

        for segment in sorted {
            if let end = currentEnd, segment.start.timeIntervalSince(end) > gapTolerance {
                sessions.append(current)
                current = []
                currentEnd = nil
            }
            current.append(segment)
            currentEnd = max(currentEnd ?? segment.end, segment.end)
        }
        if !current.isEmpty { sessions.append(current) }
        return sessions
    }

    static func isNap(session: [SleepSegment], calendar: Calendar = .current) -> Bool {
        guard let start = session.map(\.start).min(),
              let end = session.map(\.end).max() else { return false }
        let durationHours = end.timeIntervalSince(start) / 3600
        if durationHours >= 3 { return false }
        let hour = calendar.component(.hour, from: start)
        return hour >= 8 && hour < 18
    }
}
