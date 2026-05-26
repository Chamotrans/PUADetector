import Foundation
import AVFoundation
import AudioToolbox

/// Plays the "PUA detected" alert via AVSpeechSynthesizer. Coexists with the
/// active `.playAndRecord` audio session used for ASR.
@MainActor
final class VoiceAlert: NSObject {
    private let synth = AVSpeechSynthesizer()
    private var lastSpokenAt: Date = .distantPast
    private let cooldown: TimeInterval = 6

    override init() {
        super.init()
        synth.delegate = self
    }

    func play(language: AlertVoiceLanguage) {
        playOnMain(language: language)
    }

    private func playOnMain(language: AlertVoiceLanguage) {
        let now = Date()
        guard now.timeIntervalSince(lastSpokenAt) >= cooldown else { return }
        lastSpokenAt = now

        // Make sure our shared audio session is willing to play through the
        // speaker right now. If ASR has set it up as .playAndRecord this is
        // basically a no-op; if the session got knocked back to inactive by
        // an interruption we re-activate it so the synth has somewhere to go.
        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord {
                try session.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
                try session.setActive(true, options: [])
            }
            // Force output to speaker so we don't whisper into the earpiece.
            try? session.overrideOutputAudioPort(.speaker)
        } catch {
            // Non-fatal — synth will still try to speak using whatever route exists.
        }

        let utterance = AVSpeechUtterance(string: language.spokenText)
        utterance.voice = preferredVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0
        utterance.volume = 1.0

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        synth.speak(utterance)
    }

    private func preferredVoice(for language: AlertVoiceLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices
            .filter { voice in
                language.voiceLanguagePrefixes.contains { voice.language.hasPrefix($0) }
            }
            .sorted { lhs, rhs in qualityScore(lhs) > qualityScore(rhs) }
            .first
            ?? language.voiceLanguagePrefixes.compactMap { AVSpeechSynthesisVoice(language: $0) }.first
    }

    private func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        if #available(iOS 16.0, *), voice.quality == .premium { return 3 }
        if voice.quality == .enhanced { return 2 }
        return 1
    }

    func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

extension VoiceAlert: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didStart utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[VoiceAlert] started: \(utterance.speechString)")
        #endif
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[VoiceAlert] finished")
        #endif
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        #if DEBUG
        print("[VoiceAlert] cancelled")
        #endif
    }
}
