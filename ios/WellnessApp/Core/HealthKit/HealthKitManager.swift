import Foundation
import HealthKit
import Combine

/// Main manager for HealthKit data access
@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()

    @Published var isAuthorized = false
    @Published var lastSyncDate: Date?

    // HealthKit types we need to read
    private let readTypes: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
        HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKCategoryType.categoryType(forIdentifier: .mindfulSession)!,
        HKWorkoutType.workoutType()
    ]

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Heart Rate

    func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let metrics = (samples as? [HKQuantitySample])?.map { sample in
                    HealthMetric(
                        type: .heartRate,
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        unit: "bpm",
                        recordedAt: sample.startDate,
                        source: "healthkit"
                    )
                } ?? []

                continuation.resume(returning: metrics)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let metrics = (samples as? [HKQuantitySample])?.map { sample in
                    HealthMetric(
                        type: .restingHeartRate,
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        unit: "bpm",
                        recordedAt: sample.startDate,
                        source: "healthkit"
                    )
                } ?? []

                continuation.resume(returning: metrics)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - HRV

    func fetchHRVData(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let metrics = (samples as? [HKQuantitySample])?.map { sample in
                    HealthMetric(
                        type: .hrv,
                        value: sample.quantity.doubleValue(for: .secondUnit(with: .milli)),
                        unit: "ms",
                        recordedAt: sample.startDate,
                        source: "healthkit"
                    )
                } ?? []

                continuation.resume(returning: metrics)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Sleep

    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepSession] {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []
                let sessions = self?.aggregateSleepSamples(sleepSamples) ?? []
                continuation.resume(returning: sessions)
            }

            healthStore.execute(query)
        }
    }

    private func aggregateSleepSamples(_ samples: [HKCategorySample]) -> [SleepSession] {
        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []

        for sample in samples {
            if let lastSample = currentSessionSamples.last,
               sample.startDate.timeIntervalSince(lastSample.endDate) > 3600 {
                if let session = createSleepSession(from: currentSessionSamples) {
                    sessions.append(session)
                }
                currentSessionSamples = []
            }
            currentSessionSamples.append(sample)
        }

        if let session = createSleepSession(from: currentSessionSamples) {
            sessions.append(session)
        }

        return sessions
    }

    private func createSleepSession(from samples: [HKCategorySample]) -> SleepSession? {
        guard let first = samples.first, let last = samples.last else { return nil }

        var deepMinutes = 0
        var remMinutes = 0
        var lightMinutes = 0
        var awakeMinutes = 0

        for sample in samples {
            let minutes = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)

            if #available(iOS 16.0, *) {
                switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                case .asleepDeep:
                    deepMinutes += minutes
                case .asleepREM:
                    remMinutes += minutes
                case .asleepCore:
                    lightMinutes += minutes
                case .awake:
                    awakeMinutes += minutes
                case .inBed:
                    // .inBed represents the full time-in-bed period and overlaps
                    // with actual sleep stages — skip it to avoid inflating awake time
                    break
                default:
                    lightMinutes += minutes
                }
            } else {
                switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                case .asleep:
                    lightMinutes += minutes
                case .awake:
                    awakeMinutes += minutes
                case .inBed:
                    // Skip .inBed — it overlaps with sleep stages
                    break
                default:
                    break
                }
            }
        }

        return SleepSession(
            startTime: first.startDate,
            endTime: last.endDate,
            deepSleepMinutes: deepMinutes,
            remSleepMinutes: remMinutes,
            lightSleepMinutes: lightMinutes,
            awakeMinutes: awakeMinutes
        )
    }

    // MARK: - Workouts

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [ExerciseSession] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let sessions = (samples as? [HKWorkout])?.map { workout in
                    ExerciseSession(
                        exerciseType: self?.categorizeWorkout(workout) ?? .light,
                        activityName: workout.workoutActivityType.name,
                        durationMinutes: Int(workout.duration / 60),
                        caloriesBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        startedAt: workout.startDate,
                        endedAt: workout.endDate
                    )
                } ?? []

                continuation.resume(returning: sessions)
            }

            healthStore.execute(query)
        }
    }

    private func categorizeWorkout(_ workout: HKWorkout) -> ExerciseType {
        switch workout.workoutActivityType {
        case .running, .cycling, .swimming, .highIntensityIntervalTraining:
            return .vigorous
        case .walking, .hiking, .dance:
            return .moderate
        case .yoga, .pilates, .flexibility:
            return .flexibility
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return .resistance
        default:
            return .light
        }
    }

    // MARK: - Glucose

    func fetchGlucoseData(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let metrics = (samples as? [HKQuantitySample])?.map { sample in
                    HealthMetric(
                        type: .glucose,
                        value: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))),
                        unit: "mg/dL",
                        recordedAt: sample.startDate,
                        source: "healthkit"
                    )
                } ?? []

                continuation.resume(returning: metrics)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Mindfulness

    func fetchMindfulnessMinutes(from startDate: Date, to endDate: Date) async throws -> [HealthMetric] {
        let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let metrics = (samples as? [HKCategorySample])?.map { sample in
                    HealthMetric(
                        type: .mindfulness,
                        value: sample.endDate.timeIntervalSince(sample.startDate) / 60,
                        unit: "minutes",
                        recordedAt: sample.startDate,
                        source: "healthkit"
                    )
                } ?? []

                continuation.resume(returning: metrics)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() async throws {
        for type in readTypes {
            if let sampleType = type as? HKSampleType {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly)
            }
        }
    }
}

// MARK: - Errors

enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
    case queryFailed
}

// MARK: - Workout Activity Type Extension

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        default: return "Workout"
        }
    }
}
