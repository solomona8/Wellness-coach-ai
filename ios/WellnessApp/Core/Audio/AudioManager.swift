import Foundation
import AVFoundation
import Combine

/// Manages audio playback and generation for the app
@MainActor
class AudioManager: ObservableObject {
    static let shared = AudioManager()

    // Audio engine for generating tones
    private var audioEngine: AVAudioEngine?
    private var toneGenerators: [AVAudioSourceNode] = []

    // Player for local audio files
    private var audioPlayer: AVAudioPlayer?

    // Player for remote/streaming audio (podcasts)
    private var avPlayer: AVPlayer?
    private var playerObserver: Any?

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentTrackTitle: String?

    private var timer: Timer?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Sound Bath Generation

    /// Generates a binaural beat sound bath
    func startSoundBath(config: SoundBathConfig) {
        stopAll()

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)

        // Create base frequency tone (left channel)
        var leftPhase: Float = 0
        let leftFrequency = config.baseFrequency

        // Create offset frequency tone (right channel) for binaural effect
        var rightPhase: Float = 0
        let rightFrequency = config.baseFrequency + config.binauralBeatFrequency

        // Create the binaural beat source
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            let leftIncrement = (2.0 * Float.pi * leftFrequency) / sampleRate
            let rightIncrement = (2.0 * Float.pi * rightFrequency) / sampleRate

            for frame in 0..<Int(frameCount) {
                let leftSample = sin(leftPhase) * config.volume
                let rightSample = sin(rightPhase) * config.volume

                leftPhase += leftIncrement
                rightPhase += rightIncrement

                if leftPhase > 2.0 * Float.pi { leftPhase -= 2.0 * Float.pi }
                if rightPhase > 2.0 * Float.pi { rightPhase -= 2.0 * Float.pi }

                // Stereo output
                if ablPointer.count >= 2 {
                    let leftBuffer = ablPointer[0]
                    let rightBuffer = ablPointer[1]

                    let leftPtr = leftBuffer.mData?.assumingMemoryBound(to: Float.self)
                    let rightPtr = rightBuffer.mData?.assumingMemoryBound(to: Float.self)

                    leftPtr?[frame] = leftSample
                    rightPtr?[frame] = rightSample
                }
            }

            return noErr
        }

        // Add ambient pad if enabled
        if config.includeAmbientPad {
            addAmbientPad(to: engine, config: config, sampleRate: sampleRate)
        }

        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate, channels: 2)!

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mainMixer, format: stereoFormat)

        toneGenerators.append(sourceNode)

        do {
            try engine.start()
            isPlaying = true
            currentTrackTitle = config.name

            // Auto-stop after duration
            if config.durationMinutes > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(config.durationMinutes * 60)) { [weak self] in
                    self?.stopSoundBath()
                }
            }
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func addAmbientPad(to engine: AVAudioEngine, config: SoundBathConfig, sampleRate: Float) {
        // Add subtle harmonic overtones for richer sound
        let harmonics: [(frequency: Float, amplitude: Float)] = [
            (config.baseFrequency * 2, 0.3),  // Octave
            (config.baseFrequency * 3, 0.15), // Fifth
            (config.baseFrequency * 4, 0.1),  // Double octave
        ]

        for (freq, amp) in harmonics {
            var phase: Float = 0
            let increment = (2.0 * Float.pi * freq) / sampleRate

            let harmonicNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

                for frame in 0..<Int(frameCount) {
                    let sample = sin(phase) * amp * config.volume * 0.5
                    phase += increment
                    if phase > 2.0 * Float.pi { phase -= 2.0 * Float.pi }

                    for buffer in ablPointer {
                        let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
                        ptr?[frame] += sample
                    }
                }

                return noErr
            }

            let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!
            engine.attach(harmonicNode)
            engine.connect(harmonicNode, to: engine.mainMixerNode, format: stereoFormat)
            toneGenerators.append(harmonicNode)
        }
    }

    func stopSoundBath() {
        audioEngine?.stop()
        for node in toneGenerators {
            audioEngine?.detach(node)
        }
        toneGenerators.removeAll()
        audioEngine = nil
        isPlaying = false
        currentTrackTitle = nil
    }

    // MARK: - Audio File Playback

    func playAudioFile(url: URL) {
        stopAll()

        // Check if it's a remote URL (http/https) or local file
        if url.scheme == "http" || url.scheme == "https" {
            // Use AVPlayer for remote streaming
            playRemoteAudio(url: url)
        } else {
            // Use AVAudioPlayer for local files
            playLocalAudio(url: url)
        }
    }

    private func playRemoteAudio(url: URL) {
        print("🎵 Playing remote audio from: \(url)")

        let playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem)

        // Observe when duration becomes available
        playerObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                    print("🎵 Audio ready, duration: \(self?.duration ?? 0) seconds")
                } else if item.status == .failed {
                    print("🎵 Failed to load audio: \(item.error?.localizedDescription ?? "unknown error")")
                }
            }
        }

        avPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }

    private func playLocalAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            duration = audioPlayer?.duration ?? 0

            startProgressTimer()
        } catch {
            print("Failed to play local audio file: \(error)")
        }
    }

    func togglePlayPause() {
        // Check which player is active
        if let player = avPlayer {
            if isPlaying {
                player.pause()
                isPlaying = false
                timer?.invalidate()
            } else {
                player.play()
                isPlaying = true
                startProgressTimer()
            }
        } else if let player = audioPlayer {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                timer?.invalidate()
            } else {
                player.play()
                isPlaying = true
                startProgressTimer()
            }
        }
    }

    func seek(to time: TimeInterval) {
        if let player = avPlayer {
            player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
            currentTime = time
        } else {
            audioPlayer?.currentTime = time
            currentTime = time
        }
    }

    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Check which player is active
                if let avPlayer = self?.avPlayer {
                    self?.currentTime = avPlayer.currentTime().seconds
                    if avPlayer.currentItem?.status == .readyToPlay {
                        self?.duration = avPlayer.currentItem?.duration.seconds ?? 0
                    }
                    // Check if playback ended
                    if avPlayer.currentItem?.status == .failed || (self?.currentTime ?? 0) >= (self?.duration ?? 0) && (self?.duration ?? 0) > 0 {
                        self?.isPlaying = false
                        self?.timer?.invalidate()
                    }
                } else {
                    self?.currentTime = self?.audioPlayer?.currentTime ?? 0
                    if self?.audioPlayer?.isPlaying == false {
                        self?.isPlaying = false
                        self?.timer?.invalidate()
                    }
                }
            }
        }
    }

    func stopAll() {
        stopSoundBath()

        // Stop AVPlayer (remote audio)
        avPlayer?.pause()
        if let observer = playerObserver {
            avPlayer?.currentItem?.removeObserver(observer as! NSObject, forKeyPath: "status")
        }
        playerObserver = nil
        avPlayer = nil

        // Stop AVAudioPlayer (local audio)
        audioPlayer?.stop()
        audioPlayer = nil

        timer?.invalidate()
        isPlaying = false
        currentTime = 0
        duration = 0
        currentTrackTitle = nil
    }
}

// MARK: - Sound Bath Configuration

struct SoundBathConfig {
    let name: String
    let baseFrequency: Float      // Base carrier frequency in Hz
    let binauralBeatFrequency: Float  // Difference between L/R channels
    let volume: Float             // 0.0 to 1.0
    let durationMinutes: Int      // 0 for infinite
    let includeAmbientPad: Bool

    // Preset configurations based on brainwave states
    static func forSleep(duration: Int = 30) -> SoundBathConfig {
        SoundBathConfig(
            name: "Deep Sleep",
            baseFrequency: 174,        // Healing frequency
            binauralBeatFrequency: 2,  // Delta waves (0.5-4 Hz) for deep sleep
            volume: 0.3,
            durationMinutes: duration,
            includeAmbientPad: true
        )
    }

    static func forRelaxation(duration: Int = 20) -> SoundBathConfig {
        SoundBathConfig(
            name: "Deep Relaxation",
            baseFrequency: 285,        // Healing/tissue regeneration
            binauralBeatFrequency: 6,  // Theta waves (4-8 Hz) for meditation
            volume: 0.35,
            durationMinutes: duration,
            includeAmbientPad: true
        )
    }

    static func forFocus(duration: Int = 45) -> SoundBathConfig {
        SoundBathConfig(
            name: "Enhanced Focus",
            baseFrequency: 396,        // Liberating frequency
            binauralBeatFrequency: 14, // Beta waves (12-30 Hz) for focus
            volume: 0.25,
            durationMinutes: duration,
            includeAmbientPad: false
        )
    }

    static func forAnxietyRelief(duration: Int = 15) -> SoundBathConfig {
        SoundBathConfig(
            name: "Anxiety Relief",
            baseFrequency: 528,        // Love/DNA repair frequency
            binauralBeatFrequency: 10, // Alpha waves (8-12 Hz) for calm alertness
            volume: 0.3,
            durationMinutes: duration,
            includeAmbientPad: true
        )
    }

    static func forHRVRecovery(hrv: Double, duration: Int = 20) -> SoundBathConfig {
        // Customize based on HRV - lower HRV suggests more stress
        let beatFreq: Float = hrv < 30 ? 4 : (hrv < 50 ? 6 : 8)

        return SoundBathConfig(
            name: "HRV Recovery",
            baseFrequency: 432,        // Universal healing frequency
            binauralBeatFrequency: beatFreq,
            volume: 0.3,
            durationMinutes: duration,
            includeAmbientPad: true
        )
    }

    static func forSleepScore(score: Double, duration: Int = 30) -> SoundBathConfig {
        // Adjust based on sleep score
        let baseFreq: Float = score < 60 ? 174 : 285
        let beatFreq: Float = score < 60 ? 1.5 : 3

        return SoundBathConfig(
            name: "Sleep Enhancement",
            baseFrequency: baseFreq,
            binauralBeatFrequency: beatFreq,
            volume: 0.25,
            durationMinutes: duration,
            includeAmbientPad: true
        )
    }
}
