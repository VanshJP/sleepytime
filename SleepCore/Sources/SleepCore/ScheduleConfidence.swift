import Foundation

/// How much to trust tonight's personalization — pure local heuristic, no ML.
public enum ScheduleConfidence {

    /// 0…1 score from data density, regularity, and stage detail.
    public static func score(profile: HistoryProfile, goodNightsUsed: Int) -> Double {
        let nights = Double(profile.recentNights.count)
        let nightFactor = min(1.0, nights / 10.0) * 0.40

        let sriFactor: Double
        if let sri = profile.sri {
            sriFactor = (sri / 100.0) * 0.30
        } else {
            sriFactor = 0.12
        }

        let staged = profile.recentNights.contains(where: \.hasStageDetail)
        let stageFactor = staged ? 0.20 : 0.05

        let goodFactor = min(1.0, Double(goodNightsUsed) / 7.0) * 0.10

        return min(1.0, max(0.05, nightFactor + sriFactor + stageFactor + goodFactor))
    }

    public static func label(for score: Double) -> String {
        switch score {
        case 0.75...: return "High confidence"
        case 0.45..<0.75: return "Building confidence"
        default: return "Early estimate"
        }
    }
}
