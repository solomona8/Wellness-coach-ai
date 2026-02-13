import Foundation

class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    private init() {
        baseURL = URL(string: Config.apiBaseUrl)!

        // Configure session with longer timeout for podcast generation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // 2 minutes for request
        config.timeoutIntervalForResource = 180 // 3 minutes total
        session = URLSession(configuration: config)
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        // Don't use appendingPathComponent for endpoints with query strings
        // as it URL-encodes the ? and & characters
        let urlString = Config.apiBaseUrl + endpoint
        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if let token = await AuthManager.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 APIClient: Added auth token to request")
        } else {
            print("⚠️ APIClient: No auth token available - request will likely fail with 401")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                throw APIError.connectionFailed
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // Try to extract error detail from server response
            var detail: String? = nil
            if let errorBody = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                detail = errorBody.detail
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, detail: detail)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Health Data

    func batchUploadMetrics(_ metrics: [HealthMetric], deviceId: String) async throws {
        struct BatchRequest: Encodable {
            let metrics: [HealthMetric]
            let deviceId: String

            enum CodingKeys: String, CodingKey {
                case metrics
                case deviceId = "device_id"
            }
        }

        let _: EmptyResponse = try await request(
            "/health/metrics/batch",
            method: "POST",
            body: BatchRequest(metrics: metrics, deviceId: deviceId)
        )
    }

    func uploadSleepSession(_ session: SleepSession) async throws {
        let _: SleepSession = try await request(
            "/health/sleep",
            method: "POST",
            body: session
        )
    }

    func uploadExerciseSession(_ session: ExerciseSession) async throws {
        let _: ExerciseSession = try await request(
            "/health/exercise",
            method: "POST",
            body: session
        )
    }

    // MARK: - Analysis

    func getTodaysAnalysis() async throws -> DailyAnalysis {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dateStr = ISO8601DateFormatter().string(from: yesterday).prefix(10)
        return try await request("/analysis/daily/\(dateStr)")
    }

    func generateAnalysis(date: Date? = nil) async throws -> DailyAnalysis {
        struct AnalysisRequest: Encodable {
            let date: String?
            let lookbackDays: Int

            enum CodingKeys: String, CodingKey {
                case date
                case lookbackDays = "lookback_days"
            }
        }

        let dateStr = date.map { ISO8601DateFormatter().string(from: $0).prefix(10) }
        return try await request(
            "/analysis/generate",
            method: "POST",
            body: AnalysisRequest(date: dateStr.map { String($0) }, lookbackDays: 7)
        )
    }

    // MARK: - Podcast

    func getTodaysPodcast() async throws -> Podcast {
        return try await request("/podcast/today")
    }

    func getPodcastHistory(page: Int = 1, perPage: Int = 10) async throws -> PodcastListResponse {
        return try await request("/podcast/history?page=\(page)&per_page=\(perPage)")
    }

    func markPodcastListened(_ podcastId: String) async throws {
        let _: EmptyResponse = try await request(
            "/podcast/listened/\(podcastId)",
            method: "POST"
        )
    }

    func generatePodcast() async throws -> Podcast {
        return try await request(
            "/podcast/generate",
            method: "POST"
        )
    }

    // MARK: - Sound Healing

    func getSoundLibrary(category: String? = nil, targetState: String? = nil) async throws -> [SoundHealingTrack] {
        var endpoint = "/sound/library"
        var params: [String] = []
        if let category = category { params.append("category=\(category)") }
        if let targetState = targetState { params.append("target_state=\(targetState)") }
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }

        return try await request(endpoint)
    }

    func getSoundRecommendations() async throws -> [SoundRecommendation] {
        return try await request("/sound/recommendations")
    }

    // MARK: - Tracking

    func logMood(_ data: MoodEntry) async throws {
        let _: MoodEntry = try await request(
            "/tracking/mood",
            method: "POST",
            body: data
        )
    }

    func logDiet(_ data: DietEntry) async throws {
        let _: DietEntry = try await request(
            "/tracking/diet",
            method: "POST",
            body: data
        )
    }

    func logGratitude(_ data: GratitudeEntry) async throws {
        let _: GratitudeEntry = try await request(
            "/tracking/gratitude",
            method: "POST",
            body: data
        )
    }

    func logMeditation(_ data: MeditationEntry) async throws {
        let _: MeditationEntry = try await request(
            "/tracking/meditation",
            method: "POST",
            body: data
        )
    }
}

// MARK: - Response Types

struct EmptyResponse: Decodable {}

struct ServerErrorResponse: Decodable {
    let detail: String?
}

struct PodcastListResponse: Decodable {
    let podcasts: [Podcast]
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case podcasts
        case total
        case page
        case perPage = "per_page"
    }
}

struct SoundRecommendation: Codable, Identifiable {
    var id = UUID()
    let track: SoundHealingTrack?
    let type: String
    let reason: String
    let priority: Int
}

// MARK: - Tracking Entries

struct MoodEntry: Codable {
    let moodScore: Int
    let stressLevel: Int?
    let energyLevel: Int?
    let emotions: [String]
    let notes: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case moodScore = "mood_score"
        case stressLevel = "stress_level"
        case energyLevel = "energy_level"
        case emotions
        case notes
        case loggedAt = "logged_at"
    }
}

struct DietEntry: Codable {
    let mealType: String
    let description: String?
    let estimatedCalories: Int?
    let mealQualityScore: Int?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case description
        case estimatedCalories = "estimated_calories"
        case mealQualityScore = "meal_quality_score"
        case loggedAt = "logged_at"
    }
}

struct GratitudeEntry: Codable {
    let gratitudeItems: [String]
    let reflection: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case gratitudeItems = "gratitude_items"
        case reflection
        case loggedAt = "logged_at"
    }
}

struct MeditationEntry: Codable {
    let durationMinutes: Int
    let meditationType: String?
    let preSessionMood: Int?
    let postSessionMood: Int?
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case durationMinutes = "duration_minutes"
        case meditationType = "meditation_type"
        case preSessionMood = "pre_session_mood"
        case postSessionMood = "post_session_mood"
        case startedAt = "started_at"
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, detail: String?)
    case decodingError
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode, let detail):
            if let detail = detail {
                return "Server error (\(statusCode)): \(detail)"
            }
            switch statusCode {
            case 401:
                return "Not authenticated. Please sign out and sign back in."
            case 403:
                return "Access denied."
            case 404:
                return "Not found."
            case 500:
                return "Server error. Please try again later."
            case 503:
                return "Server is starting up. Please wait a moment and try again."
            default:
                return "Server error (\(statusCode))."
            }
        case .decodingError:
            return "Unexpected response format from server."
        case .connectionFailed:
            return "Could not connect to server. Please check your connection and try again."
        }
    }
}
