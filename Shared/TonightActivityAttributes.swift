import Foundation
import ActivityKit

nonisolated struct TonightActivityAttributes: ActivityAttributes, Sendable {
    public nonisolated struct ContentState: Codable, Hashable, Sendable {
        var phaseName: String
        var setpointDisplay: String
        var phaseEndDate: Date
        var tintName: String
    }

    var lightsOut: Date
    var wake: Date
}
