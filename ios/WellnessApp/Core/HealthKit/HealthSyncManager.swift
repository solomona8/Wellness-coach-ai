import Foundation
import Combine

/// Manages automatic health data syncing between HealthKit and Supabase.
/// Persists sync state and triggers sync on app launch.
@MainActor
class HealthSyncManager: ObservableObject {
    static let shared = HealthSyncManager()

    private let healthKitManager = HealthKitManager.shared
    private let uploader = HealthDataUploader.shared

    @Published var isSyncing = false
    @Published var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "lastHealthSyncDate")
            }
        }
    }
    @Published var lastSyncResult: String?
    @Published var lastSyncError: String?

    private init() {
        // Restore persisted sync date
        lastSyncDate = UserDefaults.standard.object(forKey: "lastHealthSyncDate") as? Date
    }

    // MARK: - Auto Sync on Launch

    /// Call this after the user is authenticated and HealthKit is authorized.
    /// Syncs if it's been more than 1 hour since the last sync.
    func syncIfNeeded() async {
        guard healthKitManager.isAuthorized else {
            print("📊 HealthSync: HealthKit not authorized, skipping auto-sync")
            return
        }

        guard !isSyncing else {
            print("📊 HealthSync: Already syncing, skipping")
            return
        }

        // Sync if never synced, or if last sync was more than 1 hour ago
        if let lastSync = lastSyncDate {
            let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceSync < 1 {
                print("📊 HealthSync: Last sync was \(String(format: "%.1f", hoursSinceSync * 60)) minutes ago, skipping")
                return
            }
        }

        print("📊 HealthSync: Starting auto-sync...")
        await performSync()
    }

    // MARK: - Full Sync

    /// Performs a full sync of health data from HealthKit to Supabase.
    func performSync() async {
        isSyncing = true
        lastSyncError = nil
        lastSyncResult = nil

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

        do {
            // Fetch all health data from HealthKit concurrently
            async let heartRates = healthKitManager.fetchHeartRateData(from: startDate, to: endDate)
            async let restingHR = healthKitManager.fetchRestingHeartRate(from: startDate, to: endDate)
            async let hrvData = healthKitManager.fetchHRVData(from: startDate, to: endDate)
            async let sleepData = healthKitManager.fetchSleepData(from: startDate, to: endDate)
            async let workouts = healthKitManager.fetchWorkouts(from: startDate, to: endDate)

            let (hrResults, restingHRResults, hrvResults, sleepResults, workoutResults) =
                try await (heartRates, restingHR, hrvData, sleepData, workouts)

            print("📊 HealthSync: Fetched \(hrResults.count) HR, \(restingHRResults.count) resting HR, \(hrvResults.count) HRV, \(sleepResults.count) sleep, \(workoutResults.count) workouts")

            var uploadedCount = 0

            // Upload heart rate (last 200 samples)
            let recentHR = Array(hrResults.suffix(200))
            if !recentHR.isEmpty {
                try await uploader.uploadHealthMetrics(recentHR)
                uploadedCount += recentHR.count
            }

            // Upload resting heart rate
            if !restingHRResults.isEmpty {
                try await uploader.uploadHealthMetrics(restingHRResults)
                uploadedCount += restingHRResults.count
            }

            // Upload HRV
            if !hrvResults.isEmpty {
                try await uploader.uploadHealthMetrics(hrvResults)
                uploadedCount += hrvResults.count
            }

            // Upload sleep sessions
            for sleep in sleepResults {
                try await uploader.uploadSleepSession(sleep)
                uploadedCount += 1
            }

            // Upload workouts
            for workout in workoutResults {
                try await uploader.uploadExerciseSession(workout)
                uploadedCount += 1
            }

            print("📊 HealthSync: Complete! Uploaded \(uploadedCount) records")

            lastSyncDate = Date()
            lastSyncResult = "Synced: \(recentHR.count) HR, \(restingHRResults.count) resting HR, \(hrvResults.count) HRV, \(sleepResults.count) sleep, \(workoutResults.count) workouts"
            isSyncing = false

            // Notify other views to refresh
            NotificationCenter.default.post(name: .healthDataSynced, object: nil)

        } catch {
            print("📊 HealthSync Error: \(error)")
            lastSyncError = "Sync failed: \(error.localizedDescription)"
            isSyncing = false
        }
    }

    // MARK: - Background Delivery

    /// Enable HealthKit background delivery for automatic updates.
    func enableBackgroundDelivery() async {
        do {
            try await healthKitManager.enableBackgroundDelivery()
            print("📊 HealthSync: Background delivery enabled")
        } catch {
            print("📊 HealthSync: Failed to enable background delivery: \(error)")
        }
    }
}
