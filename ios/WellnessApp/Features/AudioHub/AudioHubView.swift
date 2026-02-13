import SwiftUI

struct AudioHubView: View {
    @State private var selectedSection: AudioSection = .soundBath

    enum AudioSection: String, CaseIterable {
        case podcast = "Podcast"
        case soundBath = "Sound Bath"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(AudioSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                switch selectedSection {
                case .podcast:
                    PodcastContentView()
                case .soundBath:
                    SoundBathContentView()
                }
            }
            .navigationTitle("Audio")
        }
    }
}

// MARK: - Podcast Content (using real API)

struct PodcastContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var podcasts: [Podcast] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedPodcast: Podcast?
    @State private var showingGenerateSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Loading state
                if isLoading && podcasts.isEmpty {
                    ProgressView("Loading podcasts...")
                        .padding(40)
                }

                // Error state
                if let error = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Could not load podcasts")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadPodcasts() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(40)
                }

                // Generate New Podcast Button (always visible)
                if !isLoading && loadError == nil {
                    Button {
                        showingGenerateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Today's Podcast")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // Today's Podcast Card
                if let todaysPodcast = podcasts.first {
                    TodayPodcastCardReal(
                        podcast: todaysPodcast,
                        isPlaying: audioManager.isPlaying && selectedPodcast?.id == todaysPodcast.id,
                        currentTime: audioManager.currentTime,
                        duration: audioManager.duration,
                        onPlay: {
                            if selectedPodcast?.id == todaysPodcast.id && audioManager.isPlaying {
                                audioManager.togglePlayPause()
                            } else {
                                playPodcast(todaysPodcast)
                            }
                        },
                        onSeek: { time in
                            audioManager.seek(to: time)
                        }
                    )
                } else if !isLoading && loadError == nil {
                    // No podcast yet - offer to generate
                    GeneratePodcastCardReal {
                        showingGenerateSheet = true
                    }
                }

                // Previous Episodes
                if podcasts.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Previous Episodes")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(Array(podcasts.dropFirst())) { podcast in
                            PodcastRowReal(
                                podcast: podcast,
                                isPlaying: audioManager.isPlaying && selectedPodcast?.id == podcast.id,
                                onPlay: {
                                    if selectedPodcast?.id == podcast.id && audioManager.isPlaying {
                                        audioManager.togglePlayPause()
                                    } else {
                                        playPodcast(podcast)
                                    }
                                }
                            )
                        }
                    }
                }

                // Empty state
                if podcasts.isEmpty && !isLoading && loadError == nil {
                    podcastEmptyState
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            Task { await loadPodcasts() }
        }
        .sheet(isPresented: $showingGenerateSheet) {
            GeneratePodcastSheetReal(onGenerated: { newPodcast in
                podcasts.insert(newPodcast, at: 0)
            })
        }
    }

    private var podcastEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Your Personal Wellness Podcast")
                .font(.title3)
                .bold()

            Text("Get daily personalized audio insights based on your health data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingGenerateSheet = true
            } label: {
                HStack {
                    Image(systemName: "waveform")
                    Text("Generate Episode")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
        }
        .padding(40)
    }

    private func loadPodcasts() async {
        isLoading = true
        loadError = nil

        // Try to load history first (more reliable)
        do {
            let history = try await APIClient.shared.getPodcastHistory()
            await MainActor.run {
                podcasts = history.podcasts
                isLoading = false
            }
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .httpError(let statusCode, _):
                    if statusCode == 404 {
                        // No podcasts yet - show empty state (not an error)
                        podcasts = []
                        isLoading = false
                    } else {
                        loadError = error.localizedDescription
                        isLoading = false
                    }
                default:
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                // Check if it's a connection error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain {
                    loadError = "Could not connect to server. Make sure backend is running."
                } else {
                    loadError = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    private func playPodcast(_ podcast: Podcast) {
        selectedPodcast = podcast

        guard let audioUrlString = podcast.audioUrl,
              let audioUrl = URL(string: audioUrlString) else {
            // No audio URL - show script instead or error
            print("No audio URL available for podcast")
            return
        }

        audioManager.playAudioFile(url: audioUrl)

        // Mark as listened
        Task {
            try? await APIClient.shared.markPodcastListened(podcast.id)
        }
    }
}

// MARK: - Real Podcast Views

struct TodayPodcastCardReal: View {
    let podcast: Podcast
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onPlay: () -> Void
    let onSeek: (TimeInterval) -> Void

    @State private var showingFullScript = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S EPISODE")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)

                    Text(podcast.title ?? "Your Daily Wellness Update")
                        .font(.title3)
                        .bold()
                }

                Spacer()

                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }

            // TLDR Section
            if let tldr = podcast.tldr, !tldr.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TL;DR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)

                    Text(tldr)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Fallback to script preview if no TLDR
                Text(String(podcast.script.prefix(150)) + "...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatDuration(podcast.durationSeconds ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // View full script button
                Button {
                    showingFullScript = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("Script")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }

                if !podcast.listened {
                    Text("NEW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }

            // Playback progress
            if isPlaying || currentTime > 0 {
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { onSeek($0) }
                    ), in: 0...(duration > 0 ? duration : 1))
                    .tint(.blue)

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .sheet(isPresented: $showingFullScript) {
            NavigationStack {
                ScrollView {
                    Text(podcast.script)
                        .padding()
                }
                .navigationTitle("Full Script")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFullScript = false
                        }
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct GeneratePodcastCardReal: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("No episode for today yet")
                .font(.headline)

            Text("Generate a personalized wellness podcast based on your latest health data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onGenerate) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Episode")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct PodcastRowReal: View {
    let podcast: Podcast
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title ?? "Wellness Update")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack {
                    Text(formatDate(podcast.podcastDate))
                    Text("•")
                    Text(formatDuration(podcast.durationSeconds ?? 0))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if podcast.listened {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatDate(_ dateStr: String) -> String {
        // Try to parse the date string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: dateStr) {
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "MMM d"
                return displayFormatter.string(from: date)
            }
        }
        return dateStr
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct GeneratePodcastSheetReal: View {
    @Environment(\.dismiss) var dismiss
    @State private var isGenerating = false
    @State private var generationStatus = ""
    @State private var errorMessage: String?

    var onGenerated: (Podcast) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Generating your podcast...")
                            .font(.headline)

                        Text(generationStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Generation Failed")
                            .font(.headline)

                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Try Again") {
                            errorMessage = nil
                            generatePodcast()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 80))
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("Generate Today's Episode")
                        .font(.title2)
                        .bold()

                    Text("We'll analyze your recent health data and create a personalized audio wellness briefing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        PodcastFeatureRow(icon: "heart.fill", text: "Heart rate & HRV analysis", color: .red)
                        PodcastFeatureRow(icon: "bed.double.fill", text: "Sleep quality insights", color: .indigo)
                        PodcastFeatureRow(icon: "figure.run", text: "Activity recommendations", color: .green)
                        PodcastFeatureRow(icon: "brain.head.profile", text: "Stress & recovery tips", color: .purple)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                if !isGenerating && errorMessage == nil {
                    Button {
                        generatePodcast()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Episode")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Text("Requires backend API with Claude & ElevenLabs keys")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical)
            .navigationTitle("New Episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generatePodcast() {
        isGenerating = true
        generationStatus = "Analyzing your health data..."

        Task {
            do {
                // Update status
                await MainActor.run {
                    generationStatus = "Creating personalized insights with AI..."
                }

                // Small delay to show status
                try await Task.sleep(nanoseconds: 1_000_000_000)

                await MainActor.run {
                    generationStatus = "Generating audio with ElevenLabs..."
                }

                // Call the API
                let podcast = try await APIClient.shared.generatePodcast()

                await MainActor.run {
                    isGenerating = false
                    onGenerated(podcast)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct PodcastFeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Sound Bath Content (extracted from SoundBathView)

struct SoundBathContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var audioManager = AudioManager.shared

    @State private var selectedPreset: SoundBathPreset = .sleep
    @State private var customDuration: Int = 30
    @State private var showingCustomizer = false
    @State private var latestHRV: Double?
    @State private var latestSleepScore: Double?
    @State private var isLoadingHealth = false

    enum SoundBathPreset: String, CaseIterable {
        case sleep = "Deep Sleep"
        case relaxation = "Relaxation"
        case focus = "Focus"
        case anxiety = "Anxiety Relief"
        case hrvRecovery = "HRV Recovery"
        case sleepEnhance = "Sleep Boost"

        var icon: String {
            switch self {
            case .sleep: return "moon.stars.fill"
            case .relaxation: return "leaf.fill"
            case .focus: return "brain.head.profile"
            case .anxiety: return "heart.circle.fill"
            case .hrvRecovery: return "waveform.path.ecg"
            case .sleepEnhance: return "bed.double.fill"
            }
        }

        var color: Color {
            switch self {
            case .sleep: return .indigo
            case .relaxation: return .green
            case .focus: return .orange
            case .anxiety: return .pink
            case .hrvRecovery: return .purple
            case .sleepEnhance: return .blue
            }
        }

        var description: String {
            switch self {
            case .sleep: return "Delta waves (2 Hz) for deep, restorative sleep"
            case .relaxation: return "Theta waves (6 Hz) for meditation & calm"
            case .focus: return "Beta waves (14 Hz) for concentration"
            case .anxiety: return "Alpha waves (10 Hz) for stress relief"
            case .hrvRecovery: return "Personalized based on your HRV"
            case .sleepEnhance: return "Optimized for your sleep patterns"
            }
        }

        var recommendedDuration: Int {
            switch self {
            case .sleep: return 30
            case .relaxation: return 20
            case .focus: return 45
            case .anxiety: return 15
            case .hrvRecovery: return 20
            case .sleepEnhance: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Now Playing Card (if playing)
                if audioManager.isPlaying {
                    nowPlayingCard
                }

                // Health-Based Recommendations
                if !audioManager.isPlaying {
                    healthRecommendationsSection
                }

                // Preset Selection
                if !audioManager.isPlaying {
                    presetSelectionSection
                }

                // Info Section
                if !audioManager.isPlaying {
                    infoSection
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            Task {
                await loadHealthData()
            }
        }
        .sheet(isPresented: $showingCustomizer) {
            SoundBathCustomizerSheet(
                preset: selectedPreset,
                duration: $customDuration,
                onStart: {
                    startSoundBath(preset: selectedPreset)
                    showingCustomizer = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        VStack(spacing: 20) {
            SoundWaveAnimation()
                .frame(height: 100)

            Text(audioManager.currentTrackTitle ?? "Sound Bath")
                .font(.title2)
                .bold()

            Text("Use headphones for binaural effect")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                audioManager.stopSoundBath()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .padding(.horizontal)
    }

    // MARK: - Health Recommendations

    private var healthRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended for You")
                    .font(.headline)
                Spacer()
                if isLoadingHealth {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            if let hrv = latestHRV, hrv < 50 {
                RecommendationCard(
                    title: "Recovery Session",
                    subtitle: "Your HRV is \(Int(hrv)) ms - a recovery session may help",
                    icon: "waveform.path.ecg",
                    color: .purple
                ) {
                    startSoundBath(preset: .hrvRecovery)
                }
            }

            if let score = latestSleepScore, score < 70 {
                RecommendationCard(
                    title: "Sleep Enhancement",
                    subtitle: "Sleep score: \(Int(score))% - try this before bed",
                    icon: "moon.stars.fill",
                    color: .indigo
                ) {
                    startSoundBath(preset: .sleepEnhance)
                }
            }

            if latestHRV == nil && latestSleepScore == nil && !isLoadingHealth {
                Text("Sync health data for personalized recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Preset Selection

    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sound Bath Sessions")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SoundBathPreset.allCases, id: \.self) { preset in
                    SoundBathPresetCard(preset: preset) {
                        selectedPreset = preset
                        customDuration = preset.recommendedDuration
                        showingCustomizer = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Sound Baths")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                SoundBathInfoRow(icon: "headphones", title: "Use Headphones", description: "Binaural beats require stereo headphones")
                SoundBathInfoRow(icon: "waveform", title: "Binaural Beats", description: "Different frequencies create brainwave entrainment")
                SoundBathInfoRow(icon: "brain", title: "Brainwave States", description: "Delta=sleep, Theta=meditation, Alpha=calm, Beta=focus")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Functions

    private func loadHealthData() async {
        isLoadingHealth = true

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

        do {
            let hrvData = try await healthKitManager.fetchHRVData(from: startDate, to: endDate)
            let sleepData = try await healthKitManager.fetchSleepData(from: startDate, to: endDate)

            await MainActor.run {
                if let latest = hrvData.last {
                    latestHRV = latest.value
                }
                if let latest = sleepData.last {
                    latestSleepScore = latest.sleepScore
                }
                isLoadingHealth = false
            }
        } catch {
            await MainActor.run {
                isLoadingHealth = false
            }
        }
    }

    private func startSoundBath(preset: SoundBathPreset) {
        let config: SoundBathConfig

        switch preset {
        case .sleep:
            config = .forSleep(duration: customDuration)
        case .relaxation:
            config = .forRelaxation(duration: customDuration)
        case .focus:
            config = .forFocus(duration: customDuration)
        case .anxiety:
            config = .forAnxietyRelief(duration: customDuration)
        case .hrvRecovery:
            config = .forHRVRecovery(hrv: latestHRV ?? 40, duration: customDuration)
        case .sleepEnhance:
            config = .forSleepScore(score: latestSleepScore ?? 50, duration: customDuration)
        }

        audioManager.startSoundBath(config: config)
    }
}

// MARK: - Supporting Views for Sound Bath

struct SoundBathPresetCard: View {
    let preset: SoundBathContentView.SoundBathPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.title)
                    .foregroundColor(preset.color)

                Text(preset.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("\(preset.recommendedDuration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct SoundBathInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SoundBathCustomizerSheet: View {
    let preset: SoundBathContentView.SoundBathPreset
    @Binding var duration: Int
    let onStart: () -> Void

    let durations = [10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 50))
                        .foregroundColor(preset.color)

                    Text(preset.rawValue)
                        .font(.title2)
                        .bold()

                    Text(preset.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(durations, id: \.self) { mins in
                            Button {
                                duration = mins
                            } label: {
                                Text("\(mins) min")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(duration == mins ? preset.color : Color(.secondarySystemBackground))
                                    .foregroundColor(duration == mins ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Sound Bath")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(preset.color)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Text("Use headphones for best results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical)
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AudioHubView()
        .environmentObject(HealthKitManager.shared)
        .environmentObject(AuthManager.shared)
}
