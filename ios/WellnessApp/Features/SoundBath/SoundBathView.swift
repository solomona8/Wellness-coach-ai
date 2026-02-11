import SwiftUI

// This file is deprecated - Sound Bath functionality is now in AudioHubView
// Keeping this as a redirect for backward compatibility

struct SoundBathView: View {
    var body: some View {
        AudioHubView()
    }
}

// MARK: - Shared Views (used by AudioHubView)

struct SoundWaveAnimation: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 8)
                    .scaleEffect(y: animate ? CGFloat.random(in: 0.3...1.0) : 0.5, anchor: .bottom)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.05),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct RecommendationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(color)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

#Preview {
    SoundBathView()
        .environmentObject(HealthKitManager.shared)
}
