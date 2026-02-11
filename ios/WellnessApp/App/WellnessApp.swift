import SwiftUI

@main
struct WellnessApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            await authManager.checkSession()
        }
    }
}
