import SwiftUI

// This file is deprecated - Podcast functionality is now in AudioHubView
// Keeping this as a redirect for backward compatibility

struct PodcastView: View {
    var body: some View {
        AudioHubView()
    }
}

#Preview {
    PodcastView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(AuthManager.shared)
}
