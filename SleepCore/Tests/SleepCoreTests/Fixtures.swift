import XCTest
@testable import SleepCore

enum Fixtures {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func seg(_ start: Date, _ end: Date, _ stage: SleepStage) -> SleepSegment {
        SleepSegment(start: start, end: end, stage: stage)
    }

    static func contiguousSleep(from start: Date, hours: Double) -> [SleepSegment] {
        var segments: [SleepSegment] = []
        var cursor = start
        let stages: [SleepStage] = [.core, .deep, .core, .rem]
        var index = 0
        let end = start.addingTimeInterval(hours * 3600)
        while cursor < end {
            let next = min(cursor.addingTimeInterval(3600), end)
            segments.append(SleepSegment(start: cursor, end: next, stage: stages[index % stages.count]))
            index += 1
            cursor = next
        }
        return segments
    }

    static func detailedNight(onsetYear: Int, onsetMonth: Int, onsetDay: Int) -> [SleepSegment] {
        let d = { (dayOffset: Int, hour: Int, minute: Int) -> Date in
            date(onsetYear, onsetMonth, onsetDay + dayOffset, hour, minute)
        }
        return [
            seg(d(0, 22, 30), d(0, 23, 0), .awake),
            seg(d(0, 23, 0), d(0, 23, 30), .core),
            seg(d(0, 23, 30), d(1, 0, 30), .deep),
            seg(d(1, 0, 30), d(1, 1, 30), .core),
            seg(d(1, 1, 30), d(1, 1, 40), .awake),
            seg(d(1, 1, 40), d(1, 2, 40), .rem),
            seg(d(1, 2, 40), d(1, 3, 10), .core),
            seg(d(1, 3, 10), d(1, 3, 40), .deep),
            seg(d(1, 3, 40), d(1, 4, 40), .rem)
        ]
    }

    static func makeFeatures(
        nightKey: Date,
        sessionStart: Date,
        onset: Date,
        offset: Date,
        tstMinutes: Double,
        deepPercent: Double,
        remPercent: Double,
        sePercent: Double = 90,
        solMinutes: Double = 10,
        deepCentroidMinutes: Double? = nil,
        awakenings: [AwakeningCluster] = [],
        hasStageDetail: Bool = true
    ) -> NightFeatures {
        NightFeatures(
            nightKey: nightKey,
            sessionStart: sessionStart,
            onset: onset,
            offset: offset,
            tstMinutes: tstMinutes,
            tibMinutes: tstMinutes + solMinutes,
            sePercent: sePercent,
            solMinutes: solMinutes,
            wasoMinutes: 5,
            deepMinutes: tstMinutes * deepPercent / 100,
            remMinutes: tstMinutes * remPercent / 100,
            coreMinutes: 0,
            unspecifiedMinutes: 0,
            deepPercent: deepPercent,
            remPercent: remPercent,
            deepCentroidMinutes: deepCentroidMinutes,
            midsleep: onset.addingTimeInterval(offset.timeIntervalSince(onset) / 2),
            awakenings: awakenings,
            hasStageDetail: hasStageDetail
        )
    }

    static func stats(_ mean: Double, _ sd: Double, count: Int) -> StageStats {
        StageStats(mean: mean, sd: sd, count: count)
    }
}
