import Foundation

// MARK: - Health Metric

enum MetricType: String, Codable {
    case heartRate = "heart_rate"
    case restingHeartRate = "resting_heart_rate"
    case hrv = "hrv"
    case glucose = "glucose"
    case mindfulness = "mindfulness"
    case activeEnergy = "active_energy"
    case exerciseTime = "exercise_time"
}

struct HealthMetric: Codable, Identifiable {
    var id = UUID()
    let type: MetricType
    let value: Double
    let unit: String
    let recordedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case type = "metric_type"
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
    }
}

// MARK: - Sleep Session

struct SleepSession: Codable, Identifiable {
    var id = UUID()
    let startTime: Date
    let endTime: Date
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
    let lightSleepMinutes: Int
    let awakeMinutes: Int

    /// Total actual sleep time (deep + REM + light), not time-in-bed
    var totalDurationMinutes: Int {
        deepSleepMinutes + remSleepMinutes + lightSleepMinutes
    }

    /// Total time in bed from first sample to last sample
    var timeInBedMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var sleepScore: Double {
        guard totalDurationMinutes > 0 else { return 0 }

        var score: Double = 0

        // Duration score (max 40)
        if totalDurationMinutes >= 420 && totalDurationMinutes <= 540 {
            score += 40
        } else if totalDurationMinutes < 420 {
            score += Double(max(0, 40 * totalDurationMinutes / 420))
        } else {
            score += Double(max(0, 40 - (totalDurationMinutes - 540) / 10))
        }

        // Deep sleep score (max 20)
        let deepPct = Double(deepSleepMinutes) / Double(totalDurationMinutes) * 100
        if deepPct >= 13 && deepPct <= 23 {
            score += 20
        } else {
            score += max(0, 20 - abs(18 - deepPct) * 2)
        }

        // REM score (max 20)
        let remPct = Double(remSleepMinutes) / Double(totalDurationMinutes) * 100
        if remPct >= 20 && remPct <= 25 {
            score += 20
        } else {
            score += max(0, 20 - abs(22.5 - remPct) * 2)
        }

        // Awake penalty (max 20)
        let awakePct = Double(awakeMinutes) / Double(totalDurationMinutes) * 100
        score += max(0, 20 - awakePct * 2)

        return min(100, max(0, score))
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case lightSleepMinutes = "light_sleep_minutes"
        case awakeMinutes = "awake_minutes"
    }
}

// MARK: - Exercise Session

enum ExerciseType: String, Codable {
    case vigorous
    case moderate
    case light
    case resistance
    case flexibility
}

struct ExerciseSession: Codable, Identifiable {
    var id = UUID()
    let exerciseType: ExerciseType
    let activityName: String?
    let durationMinutes: Int
    let caloriesBurned: Double?
    let startedAt: Date
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case exerciseType = "exercise_type"
        case activityName = "activity_name"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

// MARK: - Daily Analysis

struct DailyAnalysis: Codable, Identifiable {
    let id: String
    let userId: String
    let analysisDate: String
    let summary: String
    let keyInsights: [String]
    let wellnessScores: WellnessScores
    let actionItems: [ActionItem]
    let recommendations: [Recommendation]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case analysisDate = "analysis_date"
        case summary
        case keyInsights = "key_insights"
        case wellnessScores = "wellness_scores"
        case actionItems = "action_items"
        case recommendations
    }
}

struct WellnessScores: Codable {
    let sleep: Int
    let activity: Int
    let stress: Int
    let nutrition: Int
    let mindfulness: Int
    let overall: Int
}

struct ActionItem: Codable, Identifiable {
    var id = UUID()
    let priority: Int
    let action: String
    let rationale: String
    let category: String
}

struct Recommendation: Codable, Identifiable {
    var id = UUID()
    let type: String
    let suggestion: String
    let timing: String?
    let expectedBenefit: String?

    enum CodingKeys: String, CodingKey {
        case type
        case suggestion
        case timing
        case expectedBenefit = "expected_benefit"
    }
}

// MARK: - Podcast

struct Podcast: Codable, Identifiable {
    let id: String
    let userId: String
    let podcastDate: String
    let title: String?
    let script: String
    let tldr: String?
    let audioUrl: String?
    let durationSeconds: Int?
    let listened: Bool
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case podcastDate = "podcast_date"
        case title
        case script
        case tldr
        case audioUrl = "audio_url"
        case durationSeconds = "duration_seconds"
        case listened
        case generatedAt = "generated_at"
    }
}

// MARK: - Sound Healing

struct SoundHealingTrack: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let category: String
    let frequencyHz: Double?
    let targetState: String
    let durationSeconds: Int
    let audioUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case frequencyHz = "frequency_hz"
        case targetState = "target_state"
        case durationSeconds = "duration_seconds"
        case audioUrl = "audio_url"
    }
}
