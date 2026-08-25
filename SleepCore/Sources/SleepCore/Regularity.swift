import Foundation

public enum Regularity {

    public static let binMinutes = 5
    public static var binsPerDay: Int { 24 * 60 / binMinutes }

    public static func sri(nights: [NightTimeline], calendar: Calendar = .current) -> Double? {
        guard nights.count >= 2 else { return nil }

        var bitmaps: [Date: [Bool]] = [:]
        for night in nights {
            bitmaps[night.nightKey] = asleepBitmap(for: night, calendar: calendar)
        }

        let keys = bitmaps.keys.sorted()
        var agreements: [Double] = []
        for (index, key) in keys.enumerated() where index + 1 < keys.count {
            let next = keys[index + 1]
            guard isNextCalendarDay(key, next, calendar: calendar),
                  let a = bitmaps[key], let b = bitmaps[next] else { continue }
            let matches = zip(a, b).filter { $0 == $1 }.count
            agreements.append(Double(matches) / Double(binsPerDay) * 100)
        }
        guard !agreements.isEmpty else { return nil }
        return agreements.reduce(0, +) / Double(agreements.count)
    }

    static func asleepBitmap(for night: NightTimeline, calendar: Calendar) -> [Bool] {
        var bitmap = [Bool](repeating: false, count: binsPerDay)
        guard let dayStart = noonAnchor(for: night.nightKey, calendar: calendar) else { return bitmap }
        let asleepIntervals = mergeOverlapping(night.segments.filter { $0.stage.isAsleep })

        for bin in 0..<binsPerDay {
            let center = dayStart.addingTimeInterval(Double(bin * binMinutes + binMinutes / 2) * 60)
            if asleepIntervals.contains(where: { $0.start <= center && center < $0.end }) {
                bitmap[bin] = true
            }
        }
        return bitmap
    }

    static func noonAnchor(for nightKey: Date, calendar: Calendar) -> Date? {
        let shifted = calendar.date(byAdding: .hour, value: 6, to: nightKey)
        return shifted.flatMap { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
    }

    static func isNextCalendarDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        calendar.date(byAdding: .day, value: 1, to: a) == b
    }

    public static func sri(fromBitmaps pairs: [(asleep: [Bool], nextAsleep: [Bool])]) -> Double? {
        var agreements: [Double] = []
        for pair in pairs {
            precondition(pair.asleep.count == pair.nextAsleep.count)
            let matches = zip(pair.asleep, pair.nextAsleep).filter { $0 == $1 }.count
            agreements.append(Double(matches) / Double(pair.asleep.count) * 100)
        }
        guard !agreements.isEmpty else { return nil }
        return agreements.reduce(0, +) / Double(agreements.count)
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
}
