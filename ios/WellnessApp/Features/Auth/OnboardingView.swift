import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentPage = 0
    @State private var displayName = ""
    @State private var selectedGoals: Set<String> = []
    @State private var isCompleting = false
    @State private var errorMessage: String?

    private let goals = [
        ("heart.fill", "Improve Heart Health", "heart_health"),
        ("bed.double.fill", "Better Sleep", "sleep"),
        ("figure.run", "Stay Active", "fitness"),
        ("brain.head.profile", "Reduce Stress", "stress"),
        ("leaf.fill", "Mindfulness", "mindfulness"),
        ("fork.knife", "Healthy Eating", "nutrition")
    ]

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    WelcomePage()
                        .tag(0)

                    // Page 2: Name
                    NamePage(displayName: $displayName)
                        .tag(1)

                    // Page 3: Goals
                    GoalsPage(selectedGoals: $selectedGoals, goals: goals)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        if currentPage < 2 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            Task {
                                await completeOnboarding()
                            }
                        }
                    } label: {
                        HStack {
                            if isCompleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(currentPage < 2 ? "Continue" : "Get Started")
                                    .bold()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(canContinue ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                    .disabled(!canContinue || isCompleting)
                }
                .padding()

                // Skip option
                Button("Skip for now") {
                    authManager.needsOnboarding = false
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }

    private var canContinue: Bool {
        switch currentPage {
        case 0: return true
        case 1: return !displayName.isEmpty
        case 2: return !selectedGoals.isEmpty
        default: return false
        }
    }

    private func completeOnboarding() async {
        isCompleting = true
        errorMessage = nil

        print("🚀 Starting onboarding completion...")
        print("📱 Current user: \(String(describing: authManager.currentUser))")

        do {
            guard let userId = authManager.currentUser?.id else {
                print("❌ No user ID found!")
                // Just skip onboarding if no user - they can set up later
                await MainActor.run {
                    errorMessage = "No user session. Tap 'Skip for now' to continue."
                    isCompleting = false
                }
                return
            }

            print("✅ User ID: \(userId.uuidString)")

            // Create/update user profile
            let profile = UserProfileUpload(
                id: userId.uuidString,
                displayName: displayName,
                timezone: TimeZone.current.identifier,
                preferredPodcastTime: "07:00",
                voicePreference: "nova",
                notificationSettings: ["daily_podcast": true, "weekly_summary": true],
                onboardingCompleted: true,
                healthGoals: Array(selectedGoals)
            )

            print("📤 Upserting profile to Supabase...")

            try await authManager.client
                .from("user_profiles")
                .upsert(profile)
                .execute()

            print("✅ Profile saved successfully!")

            await MainActor.run {
                authManager.needsOnboarding = false
            }
        } catch {
            print("❌ Onboarding error: \(error)")
            await MainActor.run {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isCompleting = false
        }
    }
}

// MARK: - Onboarding Pages

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.linearGradient(
                    colors: [.pink, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Welcome to\nWellness Coach AI")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Let's personalize your wellness journey with insights tailored just for you.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct NamePage: View {
    @Binding var displayName: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("What should we call you?")
                .font(.title)
                .bold()

            TextField("Your name", text: $displayName)
                .textFieldStyle(.plain)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 48)

            Text("This is how we'll greet you in your daily wellness podcasts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct GoalsPage: View {
    @Binding var selectedGoals: Set<String>
    let goals: [(String, String, String)]

    var body: some View {
        VStack(spacing: 24) {
            Text("What are your wellness goals?")
                .font(.title)
                .bold()
                .padding(.top, 32)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(goals, id: \.2) { icon, title, key in
                    GoalCard(
                        icon: icon,
                        title: title,
                        isSelected: selectedGoals.contains(key)
                    ) {
                        if selectedGoals.contains(key) {
                            selectedGoals.remove(key)
                        } else {
                            selectedGoals.insert(key)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct GoalCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .blue)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Upload Model

struct UserProfileUpload: Encodable {
    let id: String
    let displayName: String
    let timezone: String
    let preferredPodcastTime: String
    let voicePreference: String
    let notificationSettings: [String: Bool]
    let onboardingCompleted: Bool
    let healthGoals: [String]

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
}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager.shared)
}
