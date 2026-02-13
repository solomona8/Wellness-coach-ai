import SwiftUI

struct TrackingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedDate = Date()
    @State private var mood: Int = 3
    @State private var energyLevel: Int = 3
    @State private var stressLevel: Int = 3
    @State private var waterIntake: Double = 0
    @State private var caffeineIntake: Double = 0
    @State private var alcoholIntake: Double = 0
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var showingSavedAlert = false

    // HealthKit data
    @State private var todayHeartRates: [HealthMetric] = []
    @State private var todayRestingHR: [HealthMetric] = []
    @State private var todayHRV: [HealthMetric] = []
    @State private var todayGlucose: [HealthMetric] = []
    @State private var todayWorkouts: [ExerciseSession] = []
    @State private var isLoadingHealth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date picker
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)

                    // Health Data Section
                    healthDataSection

                    // Manual Entry Section
                    manualEntrySection

                    // Notes Section
                    notesSection

                    // Save Button
                    Button {
                        Task {
                            await saveEntry()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Entry")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Daily Tracking")
            .onAppear {
                Task {
                    await loadHealthData()
                }
            }
            .onChange(of: selectedDate) { _, _ in
                Task {
                    await loadHealthData()
                }
            }
            .alert("Entry Saved", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your daily tracking entry has been saved.")
            }
        }
    }

    // MARK: - Health Data Section

    private var healthDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Health Data")
                    .font(.headline)
                Spacer()
                if isLoadingHealth {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Resting Heart Rate
                HealthMetricCard(
                    icon: "heart.fill",
                    title: "Resting HR",
                    value: restingHeartRate,
                    unit: "bpm",
                    color: .red
                )

                // HRV
                HealthMetricCard(
                    icon: "waveform.path.ecg",
                    title: "Avg HRV",
                    value: averageHRV,
                    unit: "ms",
                    color: .purple
                )

                // Glucose (CGM)
                HealthMetricCard(
                    icon: "drop.fill",
                    title: "Avg Glucose",
                    value: averageGlucose,
                    unit: "mg/dL",
                    color: .orange
                )

                // Workouts
                HealthMetricCard(
                    icon: "figure.run",
                    title: "Workouts",
                    value: todayWorkouts.isEmpty ? nil : Double(todayWorkouts.count),
                    unit: "sessions",
                    color: .green
                )
            }
            .padding(.horizontal)

            // Glucose detail if available
            if !todayGlucose.isEmpty {
                glucoseDetailCard
            }
        }
    }

    private var glucoseDetailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Glucose Readings")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(todayGlucose.map { $0.value }.min() ?? 0))")
                        .font(.title2)
                        .bold()
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(Int(averageGlucose ?? 0))")
                        .font(.title2)
                        .bold()
                    Text("Avg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(Int(todayGlucose.map { $0.value }.max() ?? 0))")
                        .font(.title2)
                        .bold()
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(todayGlucose.count)")
                        .font(.title2)
                        .bold()
                    Text("Readings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Manual Entry Section

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How are you feeling?")
                .font(.headline)
                .padding(.horizontal)

            // Mood
            SliderRow(title: "Mood", value: $mood, icon: "face.smiling", color: .yellow)

            // Energy
            SliderRow(title: "Energy", value: $energyLevel, icon: "bolt.fill", color: .orange)

            // Stress
            SliderRow(title: "Stress", value: $stressLevel, icon: "brain.head.profile", color: .red)

            Divider()
                .padding(.horizontal)

            Text("Intake Tracking")
                .font(.headline)
                .padding(.horizontal)

            // Water
            IntakeRow(title: "Water", value: $waterIntake, unit: "glasses", icon: "drop.fill", color: .blue)

            // Caffeine
            IntakeRow(title: "Caffeine", value: $caffeineIntake, unit: "cups", icon: "cup.and.saucer.fill", color: .brown)

            // Alcohol
            IntakeRow(title: "Alcohol", value: $alcoholIntake, unit: "drinks", icon: "wineglass.fill", color: .purple)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .padding(.horizontal)

            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
        }
    }

    // MARK: - Computed Properties

    private var restingHeartRate: Double? {
        guard !todayRestingHR.isEmpty else { return nil }
        return todayRestingHR.last?.value
    }

    private var averageHRV: Double? {
        guard !todayHRV.isEmpty else { return nil }
        return todayHRV.map { $0.value }.reduce(0, +) / Double(todayHRV.count)
    }

    private var averageGlucose: Double? {
        guard !todayGlucose.isEmpty else { return nil }
        return todayGlucose.map { $0.value }.reduce(0, +) / Double(todayGlucose.count)
    }

    // MARK: - Functions

    private func loadHealthData() async {
        isLoadingHealth = true

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            async let heartRates = healthKitManager.fetchHeartRateData(from: startOfDay, to: endOfDay)
            async let restingHR = healthKitManager.fetchRestingHeartRate(from: startOfDay, to: endOfDay)
            async let hrv = healthKitManager.fetchHRVData(from: startOfDay, to: endOfDay)
            async let glucose = healthKitManager.fetchGlucoseData(from: startOfDay, to: endOfDay)
            async let workouts = healthKitManager.fetchWorkouts(from: startOfDay, to: endOfDay)

            let (hr, restingHRData, hrvData, glucoseData, workoutData) = try await (heartRates, restingHR, hrv, glucose, workouts)

            await MainActor.run {
                todayHeartRates = hr
                todayRestingHR = restingHRData
                todayHRV = hrvData
                todayGlucose = glucoseData
                todayWorkouts = workoutData
                isLoadingHealth = false
            }
        } catch {
            print("Error loading health data: \(error)")
            await MainActor.run {
                isLoadingHealth = false
            }
        }
    }

    private func saveEntry() async {
        isSaving = true

        // For now, just show saved alert
        // In a full implementation, this would save to Supabase
        try? await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            isSaving = false
            showingSavedAlert = true
        }
    }
}

// MARK: - Supporting Views

struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: Double?
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            if let value = value {
                Text(String(format: "%.0f", value))
                    .font(.title2)
                    .bold()
            } else {
                Text("--")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Int
    let icon: String
    let color: Color

    private let labels = ["Very Low", "Low", "Medium", "High", "Very High"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(labels[value - 1])
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Circle()
                        .fill(level <= value ? color : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("\(level)")
                                .font(.caption)
                                .foregroundColor(level <= value ? .white : .gray)
                        )
                        .onTapGesture {
                            withAnimation {
                                value = level
                            }
                        }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct IntakeRow: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Button {
                if value > 0 { value -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.gray)
            }

            Text("\(Int(value))")
                .font(.headline)
                .frame(width: 40)

            Button {
                value += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(color)
            }

            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
        }
        .padding(.horizontal)
    }
}

#Preview {
    TrackingView()
        .environmentObject(HealthKitManager.shared)
}
