import SwiftUI

@main
struct WellnessApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var syncManager = HealthSyncManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
                .environmentObject(syncManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var syncManager: HealthSyncManager

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
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && !authManager.needsOnboarding {
                Task {
                    // Auto-sync health data on login
                    await syncManager.syncIfNeeded()
                    // Enable background delivery for future updates
                    await syncManager.enableBackgroundDelivery()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if authManager.isAuthenticated {
                Task {
                    await syncManager.syncIfNeeded()
                }
            }
        }
    }
}
