import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var heartRateData: [HealthMetric] = []
    @State private var hrvData: [HealthMetric] = []
    @State private var glucoseData: [HealthMetric] = []
    @State private var sleepData: [SleepSession] = []
    @State private var workoutData: [ExerciseSession] = []
    @State private var isLoading = false

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case twoWeeks = "14 Days"
        case month = "30 Days"

        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView("Loading insights...")
                            .padding(.top, 40)
                    } else {
                        // Heart Rate Chart
                        if !heartRateData.isEmpty {
                            ChartCard(
                                title: "Heart Rate",
                                subtitle: "Range: \(Int(heartRateData.map { $0.value }.min() ?? 0))–\(Int(heartRateData.map { $0.value }.max() ?? 0)) BPM",
                                icon: "heart.fill",
                                color: .red
                            ) {
                                heartRateChart
                            }
                        }

                        // HRV Chart
                        if !hrvData.isEmpty {
                            ChartCard(
                                title: "Heart Rate Variability",
                                subtitle: "Average: \(Int(hrvData.map { $0.value }.reduce(0, +) / Double(hrvData.count))) ms",
                                icon: "waveform.path.ecg",
                                color: .purple
                            ) {
                                hrvChart
                            }
                        }

                        // Glucose Chart (CGM)
                        if !glucoseData.isEmpty {
                            ChartCard(
                                title: "Blood Glucose",
                                subtitle: "Time in range: \(timeInRange)%",
                                icon: "drop.fill",
                                color: .orange
                            ) {
                                glucoseChart
                            }

                            // Glucose Stats
                            glucoseStatsCard
                        }

                        // Sleep Chart
                        if !sleepData.isEmpty {
                            ChartCard(
                                title: "Sleep Duration",
                                subtitle: "Average: \(averageSleepHours) hrs",
                                icon: "bed.double.fill",
                                color: .indigo
                            ) {
                                sleepChart
                            }
                        }

                        // Workout Summary
                        if !workoutData.isEmpty {
                            workoutSummaryCard
                        }

                        // Empty state
                        if heartRateData.isEmpty && hrvData.isEmpty && glucoseData.isEmpty && sleepData.isEmpty {
                            emptyStateView
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            .onAppear {
                Task {
                    await loadData()
                }
            }
            .onChange(of: selectedTimeRange) { _ in
                Task {
                    await loadData()
                }
            }
        }
    }

    // MARK: - Charts

    private var heartRateChart: some View {
        Chart {
            ForEach(heartRateDailyRanges, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    yStart: .value("Min", item.min),
                    yEnd: .value("Max", item.max),
                    width: selectedTimeRange == .month ? .ratio(0.6) : .ratio(0.4)
                )
                .foregroundStyle(.red)
                .clipShape(Capsule())
            }
        }
        .frame(height: 150)
        .chartYScale(domain: heartRateYDomain)
        .chartXScale(domain: chartDateRange.start...chartDateRange.end)
        .chartXAxis {
            switch selectedTimeRange {
            case .week:
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            case .twoWeeks:
                AxisMarks(values: .stride(by: .day, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }

    private var hrvChart: some View {
        Chart {
            ForEach(aggregatedHRV, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("HRV", item.value)
                )
                .foregroundStyle(.purple)
            }
        }
        .frame(height: 150)
    }

    private var glucoseChart: some View {
        Chart {
            // Target range band
            RectangleMark(
                yStart: .value("Min", 70),
                yEnd: .value("Max", 140)
            )
            .foregroundStyle(.green.opacity(0.1))

            ForEach(aggregatedGlucose, id: \.date) { item in
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Glucose", item.value)
                )
                .foregroundStyle(glucoseColor(for: item.value))

                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Glucose", item.value)
                )
                .foregroundStyle(.orange.opacity(0.5))
            }
        }
        .frame(height: 150)
        .chartYScale(domain: 40...250)
    }

    private var sleepChart: some View {
        Chart {
            ForEach(sleepData) { session in
                BarMark(
                    x: .value("Date", session.startTime, unit: .day),
                    y: .value("Hours", Double(session.totalDurationMinutes) / 60.0)
                )
                .foregroundStyle(.indigo)
            }

            // 8 hour target line
            RuleMark(y: .value("Target", 8))
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .frame(height: 150)
    }

    // MARK: - Stats Cards

    private var glucoseStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                StatBox(title: "Average", value: "\(Int(glucoseData.map { $0.value }.reduce(0, +) / Double(max(1, glucoseData.count))))", unit: "mg/dL", color: .orange)
                StatBox(title: "Min", value: "\(Int(glucoseData.map { $0.value }.min() ?? 0))", unit: "mg/dL", color: .blue)
                StatBox(title: "Max", value: "\(Int(glucoseData.map { $0.value }.max() ?? 0))", unit: "mg/dL", color: .red)
                StatBox(title: "Readings", value: "\(glucoseData.count)", unit: "", color: .gray)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var workoutSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.green)
                Text("Workout Summary")
                    .font(.headline)
            }

            HStack(spacing: 16) {
                StatBox(title: "Workouts", value: "\(workoutData.count)", unit: "", color: .green)
                StatBox(title: "Total Time", value: "\(workoutData.reduce(0) { $0 + $1.durationMinutes })", unit: "min", color: .blue)
                StatBox(title: "Calories", value: "\(Int(workoutData.compactMap { $0.caloriesBurned }.reduce(0, +)))", unit: "kcal", color: .orange)
            }

            // Workout types breakdown
            if !workoutTypeBreakdown.isEmpty {
                Divider()
                ForEach(workoutTypeBreakdown, id: \.0) { type, count in
                    HStack {
                        Text(type)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count) sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Data Available")
                .font(.headline)

            Text("Connect HealthKit and sync your data to see insights here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Computed Properties

    private var heartRateDailyRanges: [(date: Date, min: Double, max: Double)] {
        let calendar = Calendar.current
        var dailyValues: [Date: [Double]] = [:]

        for metric in heartRateData {
            let day = calendar.startOfDay(for: metric.recordedAt)
            dailyValues[day, default: []].append(metric.value)
        }

        return dailyValues.map { (date: $0.key, min: $0.value.min() ?? 0, max: $0.value.max() ?? 0) }
            .sorted { $0.date < $1.date }
    }

    private var aggregatedHRV: [(date: Date, value: Double)] {
        aggregateByDay(hrvData)
    }

    private var aggregatedGlucose: [(date: Date, value: Double)] {
        // For glucose, show more granular data
        glucoseData.map { (date: $0.recordedAt, value: $0.value) }
    }

    private var chartDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(selectedTimeRange.days - 1), to: end)!
        return (start, end)
    }

    private var heartRateYDomain: ClosedRange<Double> {
        let values = heartRateData.map { $0.value }
        let min = (values.min() ?? 50) - 10
        let max = (values.max() ?? 100) + 10
        return min...max
    }

    private var timeInRange: Int {
        guard !glucoseData.isEmpty else { return 0 }
        let inRange = glucoseData.filter { $0.value >= 70 && $0.value <= 140 }.count
        return Int(Double(inRange) / Double(glucoseData.count) * 100)
    }

    private var averageSleepHours: String {
        guard !sleepData.isEmpty else { return "0" }
        let avgMinutes = sleepData.map { $0.totalDurationMinutes }.reduce(0, +) / sleepData.count
        return String(format: "%.1f", Double(avgMinutes) / 60.0)
    }

    private var workoutTypeBreakdown: [(String, Int)] {
        var breakdown: [String: Int] = [:]
        for workout in workoutData {
            let name = workout.activityName ?? workout.exerciseType.rawValue.capitalized
            breakdown[name, default: 0] += 1
        }
        return breakdown.sorted { $0.value > $1.value }
    }

    // MARK: - Helper Functions

    private func aggregateByDay(_ metrics: [HealthMetric]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var dailyAverages: [Date: [Double]] = [:]

        for metric in metrics {
            let day = calendar.startOfDay(for: metric.recordedAt)
            dailyAverages[day, default: []].append(metric.value)
        }

        return dailyAverages.map { (date: $0.key, value: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }

    private func glucoseColor(for value: Double) -> Color {
        if value < 70 { return .blue }
        if value > 180 { return .red }
        if value > 140 { return .yellow }
        return .green
    }

    private func loadData() async {
        isLoading = true

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate)!

        do {
            async let hr = healthKitManager.fetchHeartRateData(from: startDate, to: endDate)
            async let hrv = healthKitManager.fetchHRVData(from: startDate, to: endDate)
            async let glucose = healthKitManager.fetchGlucoseData(from: startDate, to: endDate)
            async let sleep = healthKitManager.fetchSleepData(from: startDate, to: endDate)
            async let workouts = healthKitManager.fetchWorkouts(from: startDate, to: endDate)

            let (hrData, hrvResult, glucoseResult, sleepResult, workoutResult) = try await (hr, hrv, glucose, sleep, workouts)

            await MainActor.run {
                // Sample heart rate data to avoid overwhelming the chart
                heartRateData = Array(hrData.suffix(500))
                hrvData = hrvResult
                glucoseData = glucoseResult
                sleepData = sleepResult
                workoutData = workoutResult
                isLoading = false
            }
        } catch {
            print("Error loading insights data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    InsightsView()
        .environmentObject(HealthKitManager.shared)
}
