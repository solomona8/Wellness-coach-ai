import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good \(viewModel.greeting)!")
                            .font(.title)
                            .bold()
                        Text("Here's your wellness summary")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Health Data Summary
                    if let summary = viewModel.summary {
                        HealthSummarySection(summary: summary)
                    } else if viewModel.isLoading {
                        ProgressView("Loading health data...")
                            .padding(.top, 40)
                    } else if viewModel.needsSync {
                        NeedsSyncView()
                            .padding(.horizontal)
                    } else {
                        EmptyDataView()
                            .padding()
                    }

                    // Quick Stats
                    if let summary = viewModel.summary {
                        QuickStatsSection(summary: summary)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .healthDataSynced)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Health Summary Section

struct HealthSummarySection: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Overview")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Heart Rate
                if let avgHR = summary.averageHeartRate {
                    MetricCard(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Avg Heart Rate",
                        value: "\(Int(avgHR))",
                        unit: "BPM"
                    )
                }

                // HRV
                if let avgHRV = summary.averageHRV {
                    MetricCard(
                        icon: "waveform.path.ecg",
                        iconColor: .purple,
                        title: "Avg HRV",
                        value: "\(Int(avgHRV))",
                        unit: "ms"
                    )
                }

                // Sleep
                if let sleepDuration = summary.lastSleepDuration {
                    let hours = sleepDuration / 60
                    let minutes = sleepDuration % 60
                    MetricCard(
                        icon: "bed.double.fill",
                        iconColor: .indigo,
                        title: "Last Sleep",
                        value: "\(hours)h \(minutes)m",
                        unit: ""
                    )
                }

                // Workouts
                MetricCard(
                    icon: "figure.run",
                    iconColor: .green,
                    title: "Workouts",
                    value: "\(summary.workoutsThisWeek)",
                    unit: "this week"
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .bold()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Quick Stats Section

struct QuickStatsSection: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Summary")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                StatRow(label: "Heart Rate Records", value: "\(summary.heartRateRecordCount)", icon: "heart.fill", color: .red)
                StatRow(label: "HRV Records", value: "\(summary.hrvRecordCount)", icon: "waveform.path.ecg", color: .purple)
                StatRow(label: "Sleep Sessions", value: "\(summary.sleepRecordCount)", icon: "bed.double.fill", color: .indigo)
                StatRow(label: "Total Workout Time", value: "\(summary.totalWorkoutMinutes) min", icon: "flame.fill", color: .orange)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

// MARK: - Empty States

struct NeedsSyncView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Sync Your Health Data")
                .font(.headline)

            Text("Go to Settings and tap 'Sync Health Data' to see your wellness metrics here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct EmptyDataView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Health Data Yet")
                .font(.headline)

            Text("Connect to Apple Health in Settings to start tracking your wellness.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var summary: DashboardSummary?
    @Published var isLoading = false
    @Published var needsSync = false

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    func load() async {
        isLoading = true
        await refresh()
        isLoading = false
    }

    func refresh() async {
        do {
            summary = try await HealthDataUploader.shared.fetchDashboardSummary()

            // Check if we have any data
            if let summary = summary {
                needsSync = summary.heartRateRecordCount == 0 &&
                            summary.hrvRecordCount == 0 &&
                            summary.sleepRecordCount == 0
            }
        } catch {
            print("Failed to load dashboard: \(error)")
            needsSync = true
        }
    }
}

#Preview {
    DashboardView()
}
