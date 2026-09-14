import Foundation

/// One ultradian cycle reconstructed from nightly stage *totals* when a
/// full hypnogram isn't reliable. Deep decays early → late; REM grows.
public struct SleepCycle: Sendable, Hashable, Codable {
    public let index: Int
    public let startMinutes: Double
    public let endMinutes: Double
    public let deepMinutes: Double
    public let remMinutes: Double
    public let lightMinutes: Double

    public var durationMinutes: Double { endMinutes - startMinutes }
}

/// Canonical ultradian redistribution used when HealthKit gives stage totals
/// (or when measured cycle period is unavailable). Ported from Sleep Optimizer:
/// deep ∝ 0.55^i, REM ∝ 1.55^i, light fills the residual.
public enum CycleArchitecture {

    public static let deepDecayBase = 0.55
    public static let remGrowthBase = 1.55
    public static let cyclePriorMinutes = 90.0
    public static let minCycles = 3
    public static let maxCycles = 6

    /// Build equal-length cycles that conserve deep/REM totals.
    public static func build(
        asleepMinutes: Double,
        deepMinutes: Double,
        remMinutes: Double
    ) -> [SleepCycle] {
        guard asleepMinutes >= 90 else { return [] }
        let n = max(minCycles, min(maxCycles, Int((asleepMinutes / cyclePriorMinutes).rounded())))
        var deepWeights: [Double] = []
        var remWeights: [Double] = []
        deepWeights.reserveCapacity(n)
        remWeights.reserveCapacity(n)
        for i in 0..<n {
            deepWeights.append(pow(deepDecayBase, Double(i)))
            remWeights.append(pow(remGrowthBase, Double(i)))
        }
        let deepSum = deepWeights.reduce(0, +)
        let remSum = remWeights.reduce(0, +)
        let cyc = asleepMinutes / Double(n)
        var out: [SleepCycle] = []
        out.reserveCapacity(n)
        var t = 0.0
        for i in 0..<n {
            let d = deepMinutes * deepWeights[i] / deepSum
            let r = remMinutes * remWeights[i] / remSum
            let light = max(0, cyc - d - r)
            out.append(SleepCycle(
                index: i,
                startMinutes: t,
                endMinutes: t + cyc,
                deepMinutes: d,
                remMinutes: r,
                lightMinutes: light
            ))
            t += cyc
        }
        return out
    }

    /// End of the deep-heavy window (minutes after onset): last cycle whose
    /// deep share is ≥ half the night's peak cycle deep, floored at 2 cycles.
    public static func deepWindowEndMinutes(cycles: [SleepCycle]) -> Double? {
        guard let maxDeep = cycles.map(\.deepMinutes).max(), maxDeep > 0 else { return nil }
        let threshold = maxDeep * 0.5
        var end = cycles.prefix(2).last?.endMinutes ?? 180
        for cycle in cycles where cycle.deepMinutes >= threshold {
            end = cycle.endMinutes
        }
        return end
    }

    /// Cool drop for cycle `i` as a fraction of peak cool depth.
    /// Peak deep cycle → 1.0; later cycles ease toward `remFloorFraction` (Kim 2025).
    public static func coolFraction(
        for cycle: SleepCycle,
        among cycles: [SleepCycle],
        remFloorFraction: Double = 0.7
    ) -> Double {
        let maxDeep = max(cycles.map(\.deepMinutes).max() ?? 1, 1)
        let scaled = cycle.deepMinutes / maxDeep
        return max(remFloorFraction, scaled)
    }
}
