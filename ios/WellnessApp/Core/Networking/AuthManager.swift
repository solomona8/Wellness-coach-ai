import Foundation
import Supabase

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    private let supabase: SupabaseClient

    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var authError: String?

    private init() {
        let supabaseUrl = URL(string: Config.supabaseUrl)!
        let supabaseKey = Config.supabaseAnonKey

        supabase = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey
        )
    }

    var client: SupabaseClient {
        supabase
    }

    /// Get the current access token for API calls
    func getAccessToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            print("✅ Got access token for user: \(session.user.email ?? "unknown")")
            return session.accessToken
        } catch {
            print("⚠️ Could not get access token: \(error.localizedDescription)")
            return nil
        }
    }

    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            print("✅ Session found for user: \(session.user.email ?? "unknown")")

            // Check if user has completed onboarding
            await checkOnboardingStatus()
        } catch {
            print("ℹ️ No active session: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        print("🔐 Attempting sign in for: \(email)")
        authError = nil

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
            print("✅ Sign in successful")
            await checkOnboardingStatus()
        } catch {
            print("❌ Sign in failed: \(error)")
            authError = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String) async throws {
        print("📝 Attempting sign up for: \(email)")
        authError = nil

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            // Check if we got a session (auto-confirmed) or need email confirmation
            if let session = response.session {
                currentUser = session.user
                isAuthenticated = true
                needsOnboarding = true
                print("✅ Sign up successful with immediate session")
            } else {
                // User created but needs email confirmation
                // For development, we'll set them as authenticated anyway
                currentUser = response.user
                isAuthenticated = true
                needsOnboarding = true
                print("✅ Sign up successful - user created (may need email confirmation)")
            }
        } catch {
            print("❌ Sign up failed: \(error)")
            authError = error.localizedDescription
            throw error
        }
    }
    
    func signOut() async throws {
        print("👋 Signing out...")
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
        needsOnboarding = false
        print("✅ Signed out")
    }

    func resetPassword(email: String) async throws {
        print("🔑 Requesting password reset for: \(email)")
        try await supabase.auth.resetPasswordForEmail(email)
        print("✅ Password reset email sent")
    }

    private func checkOnboardingStatus() async {
        guard let userId = currentUser?.id else {
            print("⚠️ No user ID for onboarding check")
            return
        }

        print("🔍 Checking onboarding status for user: \(userId)")

        do {
            let response = try await supabase
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()

            // Try to decode the response
            let profiles = try JSONDecoder().decode([UserProfile].self, from: response.data)

            if let profile = profiles.first {
                needsOnboarding = !profile.onboardingCompleted
                print("✅ Profile found, onboarding completed: \(profile.onboardingCompleted)")
            } else {
                // No profile exists yet
                needsOnboarding = true
                print("ℹ️ No profile found, needs onboarding")
            }
        } catch {
            // Profile might not exist yet or there was an error
            print("⚠️ Error checking profile: \(error)")
            needsOnboarding = true
        }
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case signUpFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .signUpFailed:
            return "Sign up failed. Please try again."
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        }
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    let id: String
    let displayName: String?
    let timezone: String?
    let preferredPodcastTime: String?
    let voicePreference: String?
    let notificationSettings: [String: Bool]?
    let onboardingCompleted: Bool
    let healthGoals: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case timezone
        case preferredPodcastTime = "preferred_podcast_time"
        case voicePreference = "voice_preference"
        case notificationSettings = "notification_settings"
        case onboardingCompleted = "onboarding_completed"
        case healthGoals = "health_goals"
    }

    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        preferredPodcastTime = try container.decodeIfPresent(String.self, forKey: .preferredPodcastTime)
        voicePreference = try container.decodeIfPresent(String.self, forKey: .voicePreference)
        notificationSettings = try container.decodeIfPresent([String: Bool].self, forKey: .notificationSettings)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        healthGoals = try container.decodeIfPresent([String].self, forKey: .healthGoals)
    }
}
