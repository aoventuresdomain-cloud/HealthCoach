import AVFoundation

/// Speaks rest-timer cues ("3, 2, 1, go") through headphones with the screen
/// locked, ducking music rather than stopping it (spike S3, board M0-06).
///
/// While a timer runs, a silent looping buffer keeps the audio session active
/// so iOS does not suspend the app when the phone locks. That needs
/// `UIBackgroundModes = audio` in the app's Info.plist. The session mixes with
/// other audio until the cues start, then ducks others; deactivating at the
/// end with `.notifyOthersOnDeactivation` brings the music back up.
@MainActor
final class VoiceCuePlayer: NSObject {
    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private let silence = AVAudioPlayerNode()
    private let synthesizer = AVSpeechSynthesizer()
    private var isHolding = false
    private var speechFinished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Starts keeping the app alive in the background. Call when the timer starts.
    func beginHolding() throws {
        guard !isHolding else { return }
        try session.setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers])
        try session.setActive(true)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate)) else {
            throw CueError.noAudioOutput
        }
        buffer.frameLength = buffer.frameCapacity // zero-filled: one second of silence

        engine.attach(silence)
        engine.connect(silence, to: engine.mainMixerNode, format: format)
        try engine.start()
        silence.scheduleBuffer(buffer, at: nil, options: .loops)
        silence.play()
        isHolding = true
    }

    /// Switches to ducking just before the cues, so music dips only for them.
    func duckOthers() {
        guard isHolding else { return }
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Cues still play, mixed rather than ducked; recorded in the spike notes.
        }
    }

    /// Speaks one cue and waits until it has finished.
    func say(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        await withCheckedContinuation { continuation in
            speechFinished?.resume()
            speechFinished = continuation
            synthesizer.speak(utterance)
        }
    }

    /// Stops everything and hands audio back to other apps (music un-ducks).
    func endHolding() {
        synthesizer.stopSpeaking(at: .immediate)
        speechFinished?.resume()
        speechFinished = nil
        guard isHolding else { return }
        silence.stop()
        engine.stop()
        engine.detach(silence)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        isHolding = false
    }

    enum CueError: LocalizedError {
        case noAudioOutput
        var errorDescription: String? { "No audio output available for voice cues." }
    }
}

extension VoiceCuePlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resumeSpeech() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resumeSpeech() }
    }

    private func resumeSpeech() {
        speechFinished?.resume()
        speechFinished = nil
    }
}
