import Foundation
import HealthKit
import SleepCore

actor HealthKitService {

    enum ServiceError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "HealthKit is not available on this device. Try Demo Mode to explore the app."
            }
        }
    }

    struct FetchedSegment: Sendable {
        let sourceID: String
        let segment: SleepSegment
        let timeZoneIdentifier: String?
    }

    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)
    private var observerRunning = false

    func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw ServiceError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }

    func fetchRecentSleep(days: Int, calendar: Calendar = .current) async throws -> [FetchedSegment] {
        guard HKHealthStore.isHealthDataAvailable() else { throw ServiceError.unavailable }

        let end = Date()
        let requestedStart = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let earliest = store.earliestPermittedSampleDate()
        let start = max(requestedStart, earliest)

        let windowPredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let wantedStages: [HKCategoryValueSleepAnalysis] = [.asleepDeep, .asleepREM, .asleepCore, .asleepUnspecified, .awake]
        let stagePredicates = wantedStages.compactMap { value -> NSPredicate? in
            HKCategoryValueSleepAnalysis.predicateForSamples(.equalTo, value: value)
        }
        let stagePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: stagePredicates)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [windowPredicate, stagePredicate])

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\HKCategorySample.startDate, order: .forward)],
            limit: nil
        )
        let samples = try await descriptor.result(for: store)

        return samples.compactMap { sample -> FetchedSegment? in
            guard let stage = mapValue(sample.value) else { return nil }
            guard sample.endDate > sample.startDate else { return nil }
            let tzID = sample.metadata?[HKMetadataKeyTimeZone] as? String
            return FetchedSegment(
                sourceID: sample.sourceRevision.source.bundleIdentifier,
                segment: SleepSegment(start: sample.startDate, end: sample.endDate, stage: stage),
                timeZoneIdentifier: tzID
            )
        }
    }

    func startObserving(handler: @escaping @Sendable () -> Void) {
        guard HKHealthStore.isHealthDataAvailable(), !observerRunning else { return }
        observerRunning = true

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completion, _ in
            handler()
            completion()
        }
        store.execute(query)

        Task {
            try? await store.enableBackgroundDelivery(for: sleepType, frequency: .immediate)
        }
    }

    private func mapValue(_ raw: Int) -> SleepStage? {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: raw) else { return nil }
        switch value {
        case .asleepDeep: return .deep
        case .asleepREM: return .rem
        case .asleepCore: return .core
        case .asleepUnspecified, .asleep: return .unspecified
        case .awake: return .awake
        default: return nil
        }
    }
}
