import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(0)

            TrackingView()
                .tabItem {
                    Label("Track", systemImage: "pencil.line")
                }
                .tag(1)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            AudioHubView()
                .tabItem {
                    Label("Audio", systemImage: "headphones")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(AuthManager.shared)
}
