import Foundation
import SwiftUI
import UIKit
import UserNotifications
import ActivityKit
import SleepCore

extension Activity: @retroactive @unchecked Sendable {}

@Observable
@MainActor
final class AppModel {

    enum Phase {
        case onboarding
        case ready
    }

    private static let settingsKey = "sleepytime.thermal.settings.v1"
    private static let prefsKey = "sleepytime.prefs.v1"
    private static let learningKey = "sleepytime.learning.v1"
    private static let partnerKey = "sleepytime.thermal.partner.v1"
    private static let savedScheduleKey = "sleepytime.saved.schedule.v1"
    private static let savedPartnerScheduleKey = "sleepytime.saved.partner.v1"
    private static let featuresKey = "sleepytime.features.v1"
    private static let profileKey = "sleepytime.profile.v1"
    private static let reminderIDsKey = "sleepytime.reminder.ids.v1"

    private(set) var phase: Phase = .onboarding
    private(set) var isLoading = false
    /// Soft background refresh — UI stays on cached schedule.
    private(set) var isRefreshing = false
    private(set) var timelines: [NightTimeline] = []
    private(set) var features: [NightFeatures] = []
    private(set) var profile: HistoryProfile = .canonical()
    private(set) var schedule: ThermalSchedule?
    private(set) var partnerSchedule: ThermalSchedule?
    private(set) var hasHealthAuthorization = false
    private(set) var learningState = LearningState()
    private(set) var lastNightAudit: NightThermalAudit?
    private(set) var setupCompleted = false

    private struct ScheduleFallback {
        var schedule: ThermalSchedule?
        var partner: ThermalSchedule?
    }

    private var savedFallback: ScheduleFallback?
    var errorText: String?

    var settings = ThermalSettings()
    var partnerSettings = ThermalSettings(neutralC: 27, isBiologicalSexFemale: false)
    var dualZoneEnabled = false
    var useFahrenheit = false
    var demoMode = false
    var windDownRemindersEnabled = false
    var sexSelection: SexSelection = .woman

    enum SexSelection: String, CaseIterable, Identifiable {
        case woman
        case man
        var id: String { rawValue }

        var isFemale: Bool { self == .woman }

        var displayName: String {
            switch self {
            case .woman: return "Woman"
            case .man: return "Man"
            }
        }
    }

    let calendar = Calendar.current
    private let service = HealthKitService()
    private var liveActivity: Activity<TonightActivityAttributes>?
    private var scheduledReminderIDs: [String] = []

    init() {
        loadPersisted()
    }

    var primaryIsFemale: Bool { sexSelection.isFemale }

    /// Instant open: restore ready state from disk, then refresh HealthKit asynchronously.
    func bootstrap() async {
        if setupCompleted || demoMode {
            phase = .ready
            if demoMode, features.isEmpty {
                await refreshFromSource(quiet: false)
            } else if !demoMode {
                await refreshQuietly()
            }
            ensureLiveActivity()
            startObservingIfPossible()
            return
        }

        if await service.hasPriorReadRequest() {
            setupCompleted = true
            hasHealthAuthorization = true
            persistPrefs()
            phase = .ready
            await refreshQuietly()
            ensureLiveActivity()
            startObservingIfPossible()
        }
    }

    func connectAndLoad() async {
        errorText = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.requestAuthorization()
            hasHealthAuthorization = true
            demoMode = false
            setupCompleted = true
            persistPrefs()
            await refreshFromSource(quiet: false)
            startObservingIfPossible()
            phase = .ready
            ensureLiveActivity()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func enterDemoMode() async {
        demoMode = true
        hasHealthAuthorization = false
        setupCompleted = true
        persistPrefs()
        isLoading = true
        defer { isLoading = false }
        await refreshFromSource(quiet: false)
        phase = .ready
        ensureLiveActivity()
    }

    func refresh() async {
        guard !isLoading, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshFromSource(quiet: true)
        ensureLiveActivity()
    }

    private func refreshQuietly() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshFromSource(quiet: true)
        ensureLiveActivity()
    }

    func switchToDemo(_ enabled: Bool) async {
        demoMode = enabled
        if enabled { setupCompleted = true }
        persistPrefs()
        await refresh()
    }

    func reconnectHealth() async {
        errorText = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.requestAuthorization()
            hasHealthAuthorization = true
            demoMode = false
            setupCompleted = true
            persistPrefs()
            await refreshFromSource(quiet: false)
            startObservingIfPossible()
            ensureLiveActivity()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func resetOnboarding() {
        setupCompleted = false
        demoMode = false
        phase = .onboarding
        persistPrefs()
    }

    private func startObservingIfPossible() {
        guard !demoMode else { return }
        Task { [weak self] in
            guard let model = self else { return }
            let service = model.service
            await service.startObserving { [weak model] in
                Task { @MainActor [weak model] in
                    await model?.refresh()
                }
            }
        }
    }

    private func refreshFromSource(quiet: Bool) async {
        if demoMode {
            ingest(DemoData.generate(days: 28, calendar: calendar))
            return
        }
        do {
            let fetched = try await service.fetchRecentSleep(days: 60, calendar: calendar)
            ingest(fetched.map { TaggedSegment(sourceID: $0.sourceID, segment: $0.segment, timeZoneIdentifier: $0.timeZoneIdentifier) })
            hasHealthAuthorization = true
        } catch {
            if !quiet {
                errorText = error.localizedDescription
            }
            // Keep cached schedule / features on soft refresh failure.
        }
    }

    private func ingest(_ tagged: [TaggedSegment]) {
        let nights = NightBuilder.buildNights(tagged: tagged, calendar: calendar)
        timelines = nights
        features = nights.compactMap { FeatureExtractor.features(for: $0, calendar: calendar) }

        if features.isEmpty, !demoMode, let saved = savedFallback?.schedule {
            schedule = saved
            partnerSchedule = savedFallback?.partner
            profile = ProfileBuilder.canonical()
        } else {
            profile = ProfileBuilder.profile(features: features, timelines: nights, calendar: calendar)
            rebuildSchedule()
        }
        updateLearningFromNights()
        updateLastNightAudit()
        persistFeaturesAndProfile()
        scheduleWindDownRemindersIfEnabled()
    }

    private func updateLastNightAudit() {
        guard let schedule,
              let lastFeatures = features.filter(\.isUsableNight).sorted(by: { $0.nightKey < $1.nightKey }).last,
              let timeline = timelines.first(where: { $0.nightKey == lastFeatures.nightKey }) else {
            lastNightAudit = nil
            return
        }
        lastNightAudit = ThermalCorrelation.audit(night: timeline, features: lastFeatures, schedule: schedule)
    }

    func rebuildSchedule() {
        let primary = resolvedSettings(for: .primary)
        schedule = ScheduleEngine.generate(
            profile: profile,
            settings: primary,
            anchorDay: calendar.startOfDay(for: Date()),
            targetLightsOut: nil,
            targetWake: nil,
            calendar: calendar
        )

        if dualZoneEnabled {
            let partner = resolvedSettings(for: .partner)
            partnerSchedule = ScheduleEngine.generate(
                profile: profile,
                settings: partner,
                anchorDay: calendar.startOfDay(for: Date()),
                targetLightsOut: nil,
                targetWake: nil,
                calendar: calendar
            )
        } else {
            partnerSchedule = nil
        }

        persistSchedules()
        savedFallback = ScheduleFallback(schedule: schedule, partner: partnerSchedule)
        writeSharedSnapshot()
        updateLastNightAudit()
    }

    enum BedSide {
        case primary
        case partner
    }

    func resolvedSettings(for side: BedSide) -> ThermalSettings {
        var resolved = side == .primary ? settings : partnerSettings
        let prior = side == .primary ? primaryIsFemale : (partnerSettings.isBiologicalSexFemale ?? false)
        resolved.isBiologicalSexFemale = prior
        if side == .primary {
            resolved.adaptiveCoolDepthC = AdaptiveLearning.effectiveDepthC(learningState)
        } else {
            resolved.adaptiveCoolDepthC = nil
        }
        return resolved
    }

    func schedule(for side: BedSide) -> ThermalSchedule? {
        side == .primary ? schedule : partnerSchedule
    }

    private func updateLearningFromNights() {
        guard let schedule, !demoMode else { return }
        var state = learningState
        for night in features where night.isUsableNight {
            state = AdaptiveLearning.record(state, night: night, schedule: schedule, calendar: calendar)
        }
        let baselineDeep = profile.baselineDeep.count >= 5 ? profile.baselineDeep.mean : nil
        let baselineRem = profile.baselineRem.count >= 5 ? profile.baselineRem.mean : nil
        state = AdaptiveLearning.evaluate(state, baselineDeepPercent: baselineDeep, baselineRemPercent: baselineRem)
        if state != learningState {
            learningState = state
            persistLearning()
            rebuildSchedule()
        }
    }

    var learningSummary: String? {
        guard learningState.completedTrials > 0 else { return nil }
        return String(format: "Adaptive depth %.2f°C · %d trial\(learningState.completedTrials == 1 ? "" : "s")", learningState.candidateC, learningState.completedTrials)
    }

    /// Morning hours + we have a last-night audit → show debrief on Tonight.
    var shouldShowMorningDebrief: Bool {
        guard lastNightAudit != nil else { return false }
        let hour = calendar.component(.hour, from: Date())
        return hour >= 5 && hour < 14
    }

    func applySettingChange() {
        persistSettings()
        persistPartner()
        persistPrefs()
        rebuildSchedule()
        ensureLiveActivity()
    }

    func effectiveSettings(for side: BedSide = .primary) -> ThermalSettings {
        resolvedSettings(for: side)
    }

    private func persistSchedules() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: Self.savedScheduleKey)
        }
        if let data = try? JSONEncoder().encode(partnerSchedule) {
            UserDefaults.standard.set(data, forKey: Self.savedPartnerScheduleKey)
        }
    }

    private func persistFeaturesAndProfile() {
        if let data = try? JSONEncoder().encode(features) {
            UserDefaults.standard.set(data, forKey: Self.featuresKey)
        }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
    }

    func automationText(for side: BedSide = .primary) -> String {
        guard let schedule = schedule(for: side) else { return "" }
        return AutomationExporter.exportText(
            schedule: schedule,
            settings: effectiveSettings(for: side),
            calendar: calendar,
            useFahrenheit: useFahrenheit
        )
    }

    var csvText: String {
        guard let schedule else { return "" }
        return AutomationExporter.exportCSV(schedule: schedule, settings: effectiveSettings())
    }

    func copyAutomation(for side: BedSide = .primary) {
        UIPasteboard.general.string = automationText(for: side)
    }

    private func writeSharedSnapshot() {
        guard let schedule else { return }
        let primarySnapshot = snapshot(from: schedule, settings: effectiveSettings(for: .primary), sideLabel: dualZoneEnabled ? "Side A" : nil)
        SharedScheduleStore.save(primarySnapshot)
        if let partner = partnerSchedule {
            let partnerSnapshot = snapshot(from: partner, settings: effectiveSettings(for: .partner), sideLabel: "Side B")
            SharedScheduleStore.save(partnerSnapshot, fileName: "scheduleB.json")
        }
    }

    private func snapshot(from schedule: ThermalSchedule, settings: ThermalSettings, sideLabel: String?) -> SharedScheduleSnapshot {
        let phases = schedule.phases.map { phase in
            SharedPhaseInfo(
                id: phase.id,
                name: phase.name,
                start: phase.start,
                end: phase.end,
                startDisplay: phase.start.formatted(date: .omitted, time: .shortened),
                endDisplay: phase.end.formatted(date: .omitted, time: .shortened),
                startTempDisplay: DeviceMapper.displayString(offsetC: phase.startOffsetC, settings: settings, useFahrenheit: useFahrenheit),
                endTempDisplay: DeviceMapper.displayString(offsetC: phase.endOffsetC, settings: settings, useFahrenheit: useFahrenheit),
                tint: phase.id
            )
        }
        return SharedScheduleSnapshot(
            generatedAt: Date(),
            lightsOut: schedule.lightsOut,
            wake: schedule.wake,
            phases: phases,
            deviceLabel: DeviceMapper.displayString(offsetC: 0, settings: settings, useFahrenheit: useFahrenheit),
            sri: schedule.metrics.sri,
            nightsAnalyzed: schedule.metrics.nightsAnalyzed,
            sideLabel: sideLabel
        )
    }

    func requestReminderAuthorizationAndSchedule() {
        Task { [weak self] in
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            guard let self else { return }
            self.windDownRemindersEnabled = granted
            self.persistPrefs()
            self.scheduleWindDownRemindersIfEnabled()
        }
    }

    func scheduleWindDownRemindersIfEnabled() {
        let center = UNUserNotificationCenter.current()
        if !scheduledReminderIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: scheduledReminderIDs)
        }
        guard windDownRemindersEnabled, let schedule else {
            scheduledReminderIDs = []
            UserDefaults.standard.removeObject(forKey: Self.reminderIDsKey)
            return
        }
        let leadMinutes = 15.0
        var ids: [String] = []
        for dayOffset in 0..<7 {
            guard let windDown = schedule.phases.first(where: { $0.id == "winddown" }) ?? schedule.phases.first else { continue }
            let fireDate = calendar.date(byAdding: .day, value: dayOffset, to: windDown.start)?.addingTimeInterval(-leadMinutes * 60)
            guard let fireDate, fireDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Wind-down warmth soon"
            content.body = "Start warming the bed. Goodnight's wind-down phase begins at \(windDown.start.formatted(date: .omitted, time: .shortened))."
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let y = calendar.component(.year, from: fireDate)
            let m = calendar.component(.month, from: fireDate)
            let d = calendar.component(.day, from: fireDate)
            let id = "goodnight.winddown.\(y)-\(m)-\(d)"
            ids.append(id)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
        scheduledReminderIDs = ids
        UserDefaults.standard.set(ids, forKey: Self.reminderIDsKey)
    }

    func ensureLiveActivity() {
        guard let schedule, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let windowStart = (schedule.phases.first?.start ?? schedule.lightsOut).addingTimeInterval(-15 * 60)
        if now >= schedule.wake {
            endLiveActivity()
            return
        }
        guard now >= windowStart else {
            endLiveActivity()
            return
        }
        if liveActivity == nil {
            startLiveActivity()
        } else {
            updateLiveActivityIfNeeded()
        }
    }

    func startLiveActivity() {
        guard let schedule, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity()
        guard let phase = schedule.phases.first(where: { Date() >= $0.start && Date() < $0.end })
                ?? schedule.phases.first(where: { $0.start > Date() }) else { return }
        let attributes = TonightActivityAttributes(lightsOut: schedule.lightsOut, wake: schedule.wake)
        let state = TonightActivityAttributes.ContentState(
            phaseName: phase.name,
            setpointDisplay: DeviceMapper.displayString(offsetC: phase.offset(at: Date()), settings: effectiveSettings(), useFahrenheit: useFahrenheit),
            phaseEndDate: phase.end,
            tintName: phase.id
        )
        liveActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: schedule.wake)
        )
    }

    func updateLiveActivityIfNeeded() {
        guard let activity = liveActivity, let schedule else { return }
        guard let phase = schedule.phases.first(where: { Date() >= $0.start && Date() < $0.end }) else {
            if Date() >= schedule.wake { endLiveActivity() }
            return
        }
        let state = TonightActivityAttributes.ContentState(
            phaseName: phase.name,
            setpointDisplay: DeviceMapper.displayString(offsetC: phase.offset(at: Date()), settings: effectiveSettings(), useFahrenheit: useFahrenheit),
            phaseEndDate: phase.end,
            tintName: phase.id
        )
        Task {
            await activity.update(.init(state: state, staleDate: schedule.wake))
        }
    }

    func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func persistPartner() {
        if let data = try? JSONEncoder().encode(partnerSettings) {
            UserDefaults.standard.set(data, forKey: Self.partnerKey)
        }
    }

    private func persistLearning() {
        if let data = try? JSONEncoder().encode(learningState) {
            UserDefaults.standard.set(data, forKey: Self.learningKey)
        }
    }

    private func persistPrefs() {
        let dict: [String: Any] = [
            "useFahrenheit": useFahrenheit,
            "demoMode": demoMode,
            "sexSelection": sexSelection.rawValue,
            "dualZoneEnabled": dualZoneEnabled,
            "windDownRemindersEnabled": windDownRemindersEnabled,
            "setupCompleted": setupCompleted
        ]
        UserDefaults.standard.set(dict, forKey: Self.prefsKey)
    }

    private func loadPersisted() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(ThermalSettings.self, from: data) {
            settings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.partnerKey),
           let decoded = try? JSONDecoder().decode(ThermalSettings.self, from: data) {
            partnerSettings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.learningKey),
           let decoded = try? JSONDecoder().decode(LearningState.self, from: data) {
            learningState = decoded
        }
        if let dict = UserDefaults.standard.dictionary(forKey: Self.prefsKey) {
            useFahrenheit = dict["useFahrenheit"] as? Bool ?? false
            demoMode = dict["demoMode"] as? Bool ?? false
            dualZoneEnabled = dict["dualZoneEnabled"] as? Bool ?? false
            windDownRemindersEnabled = dict["windDownRemindersEnabled"] as? Bool ?? false
            setupCompleted = dict["setupCompleted"] as? Bool ?? false
            if let raw = dict["sexSelection"] as? String {
                switch raw {
                case "male", "man": sexSelection = .man
                default: sexSelection = .woman
                }
            }
        }
        if let data = UserDefaults.standard.data(forKey: Self.savedScheduleKey),
           let decoded = try? JSONDecoder().decode(ThermalSchedule.self, from: data) {
            schedule = decoded
            if savedFallback == nil { savedFallback = ScheduleFallback(schedule: decoded, partner: nil) }
            else { savedFallback?.schedule = decoded }
        }
        if let data = UserDefaults.standard.data(forKey: Self.savedPartnerScheduleKey),
           let decoded = try? JSONDecoder().decode(ThermalSchedule.self, from: data) {
            partnerSchedule = decoded
            savedFallback?.partner = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.featuresKey),
           let decoded = try? JSONDecoder().decode([NightFeatures].self, from: data) {
            features = decoded
        }
        if let data = UserDefaults.standard.data(forKey: Self.profileKey),
           let decoded = try? JSONDecoder().decode(HistoryProfile.self, from: data) {
            profile = decoded
        }
        if let ids = UserDefaults.standard.stringArray(forKey: Self.reminderIDsKey) {
            scheduledReminderIDs = ids
        }
        if ProcessInfo.processInfo.arguments.contains("-sleepytime-fahrenheit") {
            useFahrenheit = true
        }

        // Instant ready: never re-trap Health users in onboarding.
        if setupCompleted || demoMode || schedule != nil {
            if schedule != nil && !setupCompleted && !demoMode {
                // Legacy installs that have a saved schedule but no setup flag.
                setupCompleted = true
                persistPrefs()
            }
            phase = .ready
        }
    }
}
