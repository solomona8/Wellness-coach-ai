import Foundation
import Supabase

/// Uploads health data directly to Supabase
@MainActor
class HealthDataUploader: ObservableObject {
    static let shared = HealthDataUploader()

    private var supabase: SupabaseClient {
        AuthManager.shared.client
    }

    private init() {}

    // MARK: - Upload Health Metrics

    func uploadHealthMetrics(_ metrics: [HealthMetric]) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UploadError.notAuthenticated
        }

        // Convert to upload models
        let records: [HealthMetricUpload] = metrics.map { metric in
            HealthMetricUpload(
                userId: userId.uuidString,
                metricType: metric.type.rawValue,
                value: metric.value,
                unit: metric.unit,
                recordedAt: metric.recordedAt,
                source: metric.source
            )
        }

        // Upsert in batches (insert or update on conflict)
        let batchSize = 50
        for batch in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(batch + batchSize, records.count)
            let batchRecords = Array(records[batch..<end])

            try await supabase
                .from("health_metrics")
                .upsert(batchRecords, onConflict: "user_id,metric_type,recorded_at,source")
                .execute()
        }
    }

    // MARK: - Upload Sleep Session

    func uploadSleepSession(_ session: SleepSession) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UploadError.notAuthenticated
        }

        let record = SleepSessionUpload(
            userId: userId.uuidString,
            startTime: session.startTime,
            endTime: session.endTime,
            totalDurationMinutes: session.totalDurationMinutes,  // actual sleep time (deep + REM + light)
            deepSleepMinutes: session.deepSleepMinutes,
            remSleepMinutes: session.remSleepMinutes,
            lightSleepMinutes: session.lightSleepMinutes,
            awakeMinutes: session.awakeMinutes,
            source: "healthkit"
        )

        try await supabase
            .from("sleep_sessions")
            .upsert(record, onConflict: "user_id,start_time,source")
            .execute()
    }

    // MARK: - Upload Exercise Session

    func uploadExerciseSession(_ session: ExerciseSession) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UploadError.notAuthenticated
        }

        let record = ExerciseSessionUpload(
            userId: userId.uuidString,
            exerciseType: session.exerciseType.rawValue,
            activityName: session.activityName ?? "Workout",
            durationMinutes: session.durationMinutes,
            caloriesBurned: session.caloriesBurned,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            source: "healthkit"
        )

        try await supabase
            .from("exercise_sessions")
            .upsert(record, onConflict: "user_id,started_at,source")
            .execute()
    }

    // MARK: - Fetch Summary for Dashboard

    func fetchDashboardSummary() async throws -> DashboardSummary {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw UploadError.notAuthenticated
        }

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fetch recent resting heart rate
        let restingHRResponse = try await supabase
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("metric_type", value: "resting_heart_rate")
            .gte("recorded_at", value: dateFormatter.string(from: weekAgo))
            .order("recorded_at", ascending: false)
            .limit(10)
            .execute()

        let restingHRRecords = try JSONDecoder().decode([HealthMetricResponse].self, from: restingHRResponse.data)

        // Fetch recent heart rate (for record count)
        let hrResponse = try await supabase
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("metric_type", value: "heart_rate")
            .gte("recorded_at", value: dateFormatter.string(from: yesterday))
            .order("recorded_at", ascending: false)
            .limit(100)
            .execute()

        let hrRecords = try JSONDecoder().decode([HealthMetricResponse].self, from: hrResponse.data)

        // Fetch recent HRV
        let hrvResponse = try await supabase
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("metric_type", value: "hrv")
            .gte("recorded_at", value: dateFormatter.string(from: weekAgo))
            .order("recorded_at", ascending: false)
            .limit(20)
            .execute()

        let hrvRecords = try JSONDecoder().decode([HealthMetricResponse].self, from: hrvResponse.data)

        // Fetch recent sleep
        let sleepResponse = try await supabase
            .from("sleep_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("start_time", value: dateFormatter.string(from: weekAgo))
            .order("start_time", ascending: false)
            .limit(7)
            .execute()

        let sleepRecords = try JSONDecoder().decode([SleepSessionResponse].self, from: sleepResponse.data)

        // Fetch recent workouts
        let workoutResponse = try await supabase
            .from("exercise_sessions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("started_at", value: dateFormatter.string(from: weekAgo))
            .order("started_at", ascending: false)
            .limit(10)
            .execute()

        let workoutRecords = try JSONDecoder().decode([ExerciseSessionResponse].self, from: workoutResponse.data)

        // Calculate averages
        let restingHR = restingHRRecords.isEmpty ? nil : restingHRRecords.first?.value
        let avgHRV = hrvRecords.isEmpty ? nil : hrvRecords.map { $0.value }.reduce(0, +) / Double(hrvRecords.count)
        let lastSleep = sleepRecords.first
        let totalWorkoutMinutes = workoutRecords.reduce(0) { $0 + $1.durationMinutes }

        return DashboardSummary(
            restingHeartRate: restingHR,
            averageHRV: avgHRV,
            lastSleepDuration: lastSleep?.totalDurationMinutes,
            lastSleepDate: nil, // Simplified - not parsing date string back
            workoutsThisWeek: workoutRecords.count,
            totalWorkoutMinutes: totalWorkoutMinutes,
            heartRateRecordCount: hrRecords.count,
            hrvRecordCount: hrvRecords.count,
            sleepRecordCount: sleepRecords.count
        )
    }
}

// MARK: - Upload Models (for encoding to Supabase)
// Note: Using String for dates to ensure proper ISO8601 format for Supabase

struct HealthMetricUpload: Encodable {
    let userId: String
    let metricType: String
    let value: Double
    let unit: String
    let recordedAt: String  // ISO8601 string
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case metricType = "metric_type"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
    }

    init(userId: String, metricType: String, value: Double, unit: String, recordedAt: Date, source: String) {
        self.userId = userId
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.recordedAt = ISO8601DateFormatter.supabase.string(from: recordedAt)
        self.source = source
    }
}

struct SleepSessionUpload: Encodable {
    let userId: String
    let startTime: String  // ISO8601 string
    let endTime: String    // ISO8601 string
    let totalDurationMinutes: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let lightSleepMinutes: Int
    let awakeMinutes: Int
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case totalDurationMinutes = "total_duration_minutes"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case lightSleepMinutes = "light_sleep_minutes"
        case awakeMinutes = "awake_minutes"
        case source
    }

    init(userId: String, startTime: Date, endTime: Date, totalDurationMinutes: Int, deepSleepMinutes: Int, remSleepMinutes: Int, lightSleepMinutes: Int, awakeMinutes: Int, source: String) {
        self.userId = userId
        self.startTime = ISO8601DateFormatter.supabase.string(from: startTime)
        self.endTime = ISO8601DateFormatter.supabase.string(from: endTime)
        self.totalDurationMinutes = totalDurationMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.awakeMinutes = awakeMinutes
        self.source = source
    }
}

struct ExerciseSessionUpload: Encodable {
    let userId: String
    let exerciseType: String
    let activityName: String
    let durationMinutes: Int
    let caloriesBurned: Double?
    let startedAt: String  // ISO8601 string
    let endedAt: String?   // ISO8601 string
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exerciseType = "exercise_type"
        case activityName = "activity_name"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case source
    }

    init(userId: String, exerciseType: String, activityName: String, durationMinutes: Int, caloriesBurned: Double?, startedAt: Date, endedAt: Date?, source: String) {
        self.userId = userId
        self.exerciseType = exerciseType
        self.activityName = activityName
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.startedAt = ISO8601DateFormatter.supabase.string(from: startedAt)
        self.endedAt = endedAt.map { ISO8601DateFormatter.supabase.string(from: $0) }
        self.source = source
    }
}

// MARK: - Date Formatter Extension

extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Response Models (for decoding from Supabase)

struct HealthMetricResponse: Codable {
    let id: String?
    let userId: String
    let metricType: String
    let value: Double
    let unit: String
    let recordedAt: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case metricType = "metric_type"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
    }
}

struct SleepSessionResponse: Codable {
    let id: String?
    let userId: String
    let startTime: String
    let endTime: String
    let totalDurationMinutes: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let lightSleepMinutes: Int
    let awakeMinutes: Int
    let source: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case totalDurationMinutes = "total_duration_minutes"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case lightSleepMinutes = "light_sleep_minutes"
        case awakeMinutes = "awake_minutes"
        case source
    }
}

struct ExerciseSessionResponse: Codable {
    let id: String?
    let userId: String
    let exerciseType: String
    let activityName: String?
    let durationMinutes: Int
    let caloriesBurned: Double?
    let startedAt: String
    let endedAt: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseType = "exercise_type"
        case activityName = "activity_name"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case source
    }
}

// MARK: - Dashboard Summary

struct DashboardSummary {
    let restingHeartRate: Double?
    let averageHRV: Double?
    let lastSleepDuration: Int?
    let lastSleepDate: Date?
    let workoutsThisWeek: Int
    let totalWorkoutMinutes: Int
    let heartRateRecordCount: Int
    let hrvRecordCount: Int
    let sleepRecordCount: Int
}

// MARK: - Errors

enum UploadError: Error, LocalizedError {
    case notAuthenticated
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in again."
        case .uploadFailed:
            return "Failed to upload health data."
        }
    }
}
