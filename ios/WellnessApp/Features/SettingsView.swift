import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @State private var isRequestingPermission = false
    @State private var isSyncing = false
    @State private var showingSignOutAlert = false
    @State private var lastSyncDate: Date?
    @State private var syncError: String?
    @State private var syncResults: String?
    @State private var showHealthKitAlert = false
    @State private var healthKitAlertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // Health Data Section
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Health")
                                .font(.headline)

                            if healthKitManager.isAuthorized {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not connected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if healthKitManager.isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button {
                                requestHealthKitAccess()
                            } label: {
                                if isRequestingPermission {
                                    ProgressView()
                                } else {
                                    Text("Connect")
                                        .font(.subheadline)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRequestingPermission)
                        }
                    }
                    .padding(.vertical, 4)

                    if healthKitManager.isAuthorized {
                        Button {
                            syncHealthData()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sync Health Data")
                                    if let lastSync = lastSyncDate {
                                        Text("Last synced: \(lastSync.formatted(.relative(presentation: .named)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if isSyncing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSyncing)

                        if let error = syncError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if let results = syncResults {
                            Text(results)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("Health Data")
                } footer: {
                    if !healthKitManager.isAuthorized {
                        Text("Connect to Apple Health to automatically sync your heart rate, sleep, exercise, and more.")
                    } else {
                        Text("Your health data is synced to provide personalized wellness insights.")
                    }
                }

                // Data Types Section
                if healthKitManager.isAuthorized {
                    Section("Synced Data Types") {
                        HealthDataTypeRow(icon: "heart.fill", color: .red, title: "Heart Rate")
                        HealthDataTypeRow(icon: "waveform.path.ecg", color: .red, title: "Heart Rate Variability")
                        HealthDataTypeRow(icon: "bed.double.fill", color: .purple, title: "Sleep Analysis")
                        HealthDataTypeRow(icon: "figure.run", color: .green, title: "Workouts")
                        HealthDataTypeRow(icon: "flame.fill", color: .orange, title: "Active Energy")
                        HealthDataTypeRow(icon: "brain.head.profile", color: .blue, title: "Mindfulness")
                    }
                }

                // Account Section
                Section("Account") {
                    if let user = authManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text(user.email ?? "No email")
                        }
                    }

                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 30)
                            Text("Sign Out")
                        }
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("HealthKit", isPresented: $showHealthKitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthKitAlertMessage)
            }
        }
    }

    private func requestHealthKitAccess() {
        isRequestingPermission = true

        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    healthKitAlertMessage = "HealthKit access granted! You can now sync your health data."
                    showHealthKitAlert = true
                }
            } catch {
                await MainActor.run {
                    healthKitAlertMessage = "HealthKit error: \(error.localizedDescription)"
                    showHealthKitAlert = true
                }
            }
            await MainActor.run {
                isRequestingPermission = false
            }
        }
    }

    private func syncHealthData() {
        isSyncing = true
        syncError = nil
        syncResults = nil

        Task {
            do {
                // Sync last 7 days of data
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

                print("📊 Starting health data sync from \(startDate) to \(endDate)")

                // Fetch all health data
                let heartRates = try await healthKitManager.fetchHeartRateData(from: startDate, to: endDate)
                print("❤️ Fetched \(heartRates.count) heart rate samples")

                let hrvData = try await healthKitManager.fetchHRVData(from: startDate, to: endDate)
                print("💓 Fetched \(hrvData.count) HRV samples")

                let sleepData = try await healthKitManager.fetchSleepData(from: startDate, to: endDate)
                print("😴 Fetched \(sleepData.count) sleep sessions")

                let workouts = try await healthKitManager.fetchWorkouts(from: startDate, to: endDate)
                print("🏃 Fetched \(workouts.count) workouts")

                // Upload to Supabase
                var uploadedCount = 0

                // Upload heart rate (sample - just last 100 to avoid overwhelming)
                let recentHR = Array(heartRates.suffix(100))
                if !recentHR.isEmpty {
                    print("⬆️ Uploading \(recentHR.count) heart rate records...")
                    try await HealthDataUploader.shared.uploadHealthMetrics(recentHR)
                    uploadedCount += recentHR.count
                    print("✅ Heart rate upload complete")
                }

                // Upload HRV
                if !hrvData.isEmpty {
                    print("⬆️ Uploading \(hrvData.count) HRV records...")
                    try await HealthDataUploader.shared.uploadHealthMetrics(hrvData)
                    uploadedCount += hrvData.count
                    print("✅ HRV upload complete")
                }

                // Upload sleep sessions
                for (index, sleep) in sleepData.enumerated() {
                    print("⬆️ Uploading sleep session \(index + 1)/\(sleepData.count)...")
                    try await HealthDataUploader.shared.uploadSleepSession(sleep)
                    uploadedCount += 1
                }
                if !sleepData.isEmpty {
                    print("✅ Sleep upload complete")
                }

                // Upload workouts
                for (index, workout) in workouts.enumerated() {
                    print("⬆️ Uploading workout \(index + 1)/\(workouts.count)...")
                    try await HealthDataUploader.shared.uploadExerciseSession(workout)
                    uploadedCount += 1
                }
                if !workouts.isEmpty {
                    print("✅ Workout upload complete")
                }

                print("🎉 Sync complete! Uploaded \(uploadedCount) records total")

                await MainActor.run {
                    lastSyncDate = Date()
                    syncResults = "Synced: \(recentHR.count) HR, \(hrvData.count) HRV, \(sleepData.count) sleep, \(workouts.count) workouts"
                    isSyncing = false

                    // Notify that data was synced
                    NotificationCenter.default.post(name: .healthDataSynced, object: nil)
                }
            } catch {
                print("❌ Sync error: \(error)")
                await MainActor.run {
                    syncError = "Sync failed: \(error.localizedDescription)"
                    isSyncing = false
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let healthDataSynced = Notification.Name("healthDataSynced")
}

// MARK: - Alerts

extension SettingsView {
    var healthKitAlert: Alert {
        Alert(
            title: Text("HealthKit"),
            message: Text(healthKitAlertMessage),
            dismissButton: .default(Text("OK"))
        )
    }
}

struct HealthDataTypeRow: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
            Spacer()
            Image(systemName: "checkmark")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
