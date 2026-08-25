import Foundation
import SleepCore

enum DemoData {

    static let sourceID = "com.vansh.sleepytime.demo"

    struct SeededRandom {
        var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        }

        mutating func next() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 1_000_000) / 1_000_000
        }

        mutating func range(_ low: Double, _ high: Double) -> Double {
            low + next() * (high - low)
        }
    }

    static func generate(days: Int = 24, calendar: Calendar = .current) -> [TaggedSegment] {
        var rng = SeededRandom(seed: 0xC0FFEE)
        var segments: [TaggedSegment] = []
        let today = calendar.startOfDay(for: Date())

        for nightOffset in stride(from: days, through: 1, by: -1) {
            let evening = calendar.date(byAdding: .day, value: -nightOffset, to: today) ?? today
            let weekday = calendar.component(.weekday, from: evening)
            let isWeekendNight = weekday == 6 || weekday == 7 || weekday == 1
            let drift: Double = isWeekendNight ? rng.range(20, 95) : rng.range(-30, 25)
            let bedHour = 22.0 + (drift + rng.range(-12, 12)) / 60.0
            let bedtime = evening.addingTimeInterval(bedHour * 3600)

            let solMinutes = rng.range(8, 28)
            var cursor = bedtime.addingTimeInterval(solMinutes * 60)

            let targetTSTHours = rng.range(rng.range(6.6, 7.4), rng.range(7.6, 8.5))
            let end = cursor.addingTimeInterval(targetTSTHours * 3600)

            var deepBudget = rng.range(75, 105)
            var remBudget = rng.range(100, 140)
            let totalAsleepSeconds = end.timeIntervalSince(cursor)
            var cycles = 0

            while cursor < end.addingTimeInterval(-15 * 60) {
                cycles += 1
                let cycleProgress = Double(cycles) / 5.2

                let coreMinutes = rng.range(45, 68)
                let coreDuration = min(coreMinutes * 60, end.timeIntervalSince(cursor))
                if coreDuration < 240 { break }
                append(segments: &segments, start: cursor, duration: coreDuration, stage: .core)
                cursor = cursor.addingTimeInterval(coreDuration)

                if deepBudget > 0 && cycleProgress < 0.75 {
                    let deepMinutes = min(deepBudget, rng.range(16, 34) * max(0.3, 1 - cycleProgress))
                    let deepDuration = min(deepMinutes * 60, end.timeIntervalSince(cursor))
                    if deepDuration >= 240 {
                        append(segments: &segments, start: cursor, duration: deepDuration, stage: .deep)
                        cursor = cursor.addingTimeInterval(deepDuration)
                        deepBudget -= deepDuration / 60
                    }
                } else if remBudget > 0 {
                    let remMinutes = min(remBudget, rng.range(14, 30) * max(0.4, cycleProgress + 0.5))
                    let remDuration = min(remMinutes * 60, end.timeIntervalSince(cursor))
                    if remDuration >= 240 {
                        append(segments: &segments, start: cursor, duration: remDuration, stage: .rem)
                        cursor = cursor.addingTimeInterval(remDuration)
                        remBudget -= remDuration / 60
                    }
                }

                if rng.next() < 0.45 && cursor < end.addingTimeInterval(-10 * 60) {
                    let wakeDuration = rng.range(3, 8) * 60
                    append(segments: &segments, start: cursor, duration: wakeDuration, stage: .awake)
                    cursor = cursor.addingTimeInterval(wakeDuration)
                }
            }

            _ = totalAsleepSeconds
        }

        return segments
    }

    private static func append(segments: inout [TaggedSegment], start: Date, duration: TimeInterval, stage: SleepStage) {
        guard duration > 60 else { return }
        segments.append(TaggedSegment(
            sourceID: sourceID,
            segment: SleepSegment(start: start, end: start.addingTimeInterval(duration), stage: stage)
        ))
    }
}
