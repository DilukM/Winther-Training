import Foundation
import AVFoundation

public class ElevenLabsTTSService: NSObject {
    static let shared = ElevenLabsTTSService()

    private let apiKey: String
    private let voiceId: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var audioPlayer: AVAudioPlayer?
    private let speechSynth = AVSpeechSynthesizer()

    private override init() {
        // Load API key from Info.plist or .env file
        self.apiKey = Self.loadAPIKey()
        self.voiceId = Self.loadVoiceId()

        // Configure audio session for playback (override Silent switch and duck others)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private static func loadAPIKey() -> String {
        // Prefer Info.plist for secrets in apps
        if let key = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String, !key.isEmpty {
            return key
        }
        // Fallback to .env bundled as resource (only if you explicitly add it to the target)
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil),
           let envContent = try? String(contentsOfFile: envPath) {
            for line in envContent.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("ELEVENLABS_API_KEY=") {
                    return String(trimmed.dropFirst("ELEVENLABS_API_KEY=".count))
                }
            }
        } else {
            print("Warning: ELEVENLABS_API_KEY not found in Info.plist and .env file not found or unreadable")
        }
        return ""
    }

    private static func loadVoiceId() -> String {
        if let voice = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_VOICE_ID") as? String, !voice.isEmpty {
            return voice
        }
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil),
           let envContent = try? String(contentsOfFile: envPath) {
            for line in envContent.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("ELEVENLABS_VOICE_ID=") {
                    return String(trimmed.dropFirst("ELEVENLABS_VOICE_ID=".count))
                }
            }
        }
        return "21m00Tcm4TlvDq8ikWAM" // Default voice ID (Rachel)
    }

    func speak(text: String, completion: ((Bool) -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?(true)
            return
        }

        // If no API key, fallback to on-device TTS so voice prompts are still audible
        guard !apiKey.isEmpty else {
            print("ElevenLabs API key not configured. Falling back to AVSpeechSynthesizer.")
            fallbackSpeak(text: text)
            completion?(true)
            return
        }

        let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            // Consider newer models like "eleven_multilingual_v2" or "eleven_turbo_v2" if available on your account
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to encode request body: \(error)")
            fallbackSpeak(text: text)
            completion?(false)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("TTS request failed: \(error)")
                DispatchQueue.main.async {
                    self?.fallbackSpeak(text: text)
                    completion?(false)
                }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                print("No HTTPURLResponse from TTS API")
                DispatchQueue.main.async {
                    self?.fallbackSpeak(text: text)
                    completion?(false)
                }
                return
            }

            guard http.statusCode == 200, let data = data, !data.isEmpty else {
                if let data = data, let message = String(data: data, encoding: .utf8) {
                    print("TTS API error (status: \(http.statusCode)): \(message)")
                } else {
                    print("TTS API error (status: \(http.statusCode)) with no body")
                }
                DispatchQueue.main.async {
                    self?.fallbackSpeak(text: text)
                    completion?(false)
                }
                return
            }

            // Play the audio data
            DispatchQueue.main.async {
                self?.playAudio(data: data, completion: completion)
            }
        }.resume()
    }

    private func playAudio(data: Data, completion: ((Bool) -> Void)? = nil) {
        do {
            // Stop any ongoing system speech
            if (speechSynth.isSpeaking) { speechSynth.stopSpeaking(at: .immediate) }
            // Stop any current audio
            audioPlayer?.stop(); audioPlayer = nil

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            completion?(true)
        } catch {
            print("Failed to play audio: \(error)")
            fallbackSpeak(text: "\n\(error.localizedDescription)")
            completion?(false)
        }
    }

    private func fallbackSpeak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        speechSynth.speak(utterance)
    }

    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        if speechSynth.isSpeaking { speechSynth.stopSpeaking(at: .immediate) }
    }
}

extension ElevenLabsTTSService: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Audio playback finished
        print("TTS playback finished successfully: \(flag)")
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?){
        print("TTS audio decode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}


 