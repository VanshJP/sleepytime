import Foundation

nonisolated struct SharedPhaseInfo: Codable, Sendable, Hashable {
    var id: String
    var name: String
    var start: Date
    var end: Date
    var startDisplay: String
    var endDisplay: String
    var startTempDisplay: String
    var endTempDisplay: String
    var tint: String

    enum CodingKeys: String, CodingKey {
        case id, name, start, end, startDisplay, endDisplay, startTempDisplay, endTempDisplay, tint
    }

    init(
        id: String,
        name: String,
        start: Date,
        end: Date,
        startDisplay: String,
        endDisplay: String,
        startTempDisplay: String = "",
        endTempDisplay: String = "",
        tint: String
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.startDisplay = startDisplay
        self.endDisplay = endDisplay
        self.startTempDisplay = startTempDisplay
        self.endTempDisplay = endTempDisplay
        self.tint = tint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        startDisplay = try c.decode(String.self, forKey: .startDisplay)
        endDisplay = try c.decode(String.self, forKey: .endDisplay)
        startTempDisplay = try c.decodeIfPresent(String.self, forKey: .startTempDisplay) ?? ""
        endTempDisplay = try c.decodeIfPresent(String.self, forKey: .endTempDisplay) ?? ""
        tint = try c.decode(String.self, forKey: .tint)
    }
}

nonisolated struct SharedScheduleSnapshot: Codable, Sendable {
    var generatedAt: Date
    var lightsOut: Date
    var wake: Date
    var phases: [SharedPhaseInfo]
    var deviceLabel: String
    var sri: Double?
    var nightsAnalyzed: Int
    var sideLabel: String?

    func currentOrNextPhase(at date: Date = Date()) -> SharedPhaseInfo? {
        if let active = phases.first(where: { date >= $0.start && date < $0.end }) {
            return active
        }
        return phases.first(where: { $0.start > date })
    }
}

nonisolated enum SharedScheduleStore {

    static let appGroupID = "group.com.vansh.sleepytime"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    static func save(_ snapshot: SharedScheduleSnapshot, fileName: String = "schedule.json") {
        guard let dir = containerURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
    }

    static func load() -> SharedScheduleSnapshot? {
        guard let dir = containerURL(),
              let data = try? Data(contentsOf: dir.appendingPathComponent("schedule.json")) else { return nil }
        return try? JSONDecoder().decode(SharedScheduleSnapshot.self, from: data)
    }
}
