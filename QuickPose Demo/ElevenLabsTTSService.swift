import Foundation
import AVFoundation

public class ElevenLabsTTSService: NSObject {
    static let shared = ElevenLabsTTSService()

    private let apiKey: String
    private let voiceId: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var audioPlayer: AVAudioPlayer?

    private override init() {
        // Load API key and Voice ID from .env bundled in the app
        self.apiKey = Self.loadAPIKey()
        self.voiceId = Self.loadVoiceId()
        print("[TTS] API Key loaded: \(Self.masked(apiKey)) | VoiceId: \(Self.masked(voiceId, show: 6))")

        // Configure audio session for playback (override Silent switch, duck/mix with others)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
            Self.logAudioSessionRoute(prefix: "[TTS] AudioSession configured")
        } catch {
            print("[TTS][Error] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - .env Loading
    private static var cachedEnv: [String: String]? = nil

    private static func loadEnv() -> [String: String] {
        if let cached = cachedEnv { return cached }
        guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("[TTS][Error] .env not found in app bundle. Ensure .env is added to the target's Copy Bundle Resources.")
            cachedEnv = [:]; return [:]
        }
        do {
            let content = try String(contentsOfFile: envPath)
            var dict: [String: String] = [:]
            for raw in content.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty || line.hasPrefix("#") { continue }
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                // Strip surrounding quotes if any
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                dict[key] = value
            }
            cachedEnv = dict
            print("[TTS] Loaded .env from \(envPath). Keys: \(dict.keys.sorted())")
            return dict
        } catch {
            print("[TTS][Error] Failed reading .env at \(envPath): \(error)")
            cachedEnv = [:]
            return [:]
        }
    }

    private static func envValue(for key: String) -> String? {
        let value = loadEnv()[key]
        if let value, !value.isEmpty {
            print("[TTS] .env \(key) found: \(masked(value))")
            return value
        } else {
            print("[TTS][Warn] .env \(key) missing or empty")
            return nil
        }
    }

    private static func masked(_ value: String, show: Int = 4) -> String {
        guard !value.isEmpty else { return "<empty>" }
        if value.count <= show { return value }
        let prefix = value.prefix(show)
        return "\(prefix)…(len=\(value.count))"
    }

    private static func loadAPIKey() -> String {
        // Only use .env
        return envValue(for: "ELEVENLABS_API_KEY") ?? ""
    }

    private static func loadVoiceId() -> String {
        // Only use .env; default if not present
        return envValue(for: "ELEVENLABS_VOICE_ID") ?? "21m00Tcm4TlvDq8ikWAM"
    }

    // MARK: - Speak
    func speak(text: String, completion: ((Bool) -> Void)? = nil) {
        guard !text.isEmpty else { completion?(true); return }

        guard !apiKey.isEmpty else {
            print("[TTS][Error] API key not configured via .env. Cannot speak. Text(len=\(text.count)).")
            print("[TTS][Hint] Ensure .env is added to target resources and contains ELEVENLABS_API_KEY=<your_key>.")
            completion?(false)
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
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]
        print("[TTS] Requesting TTS. VoiceId=\(Self.masked(voiceId, show: 6)) TextLen=\(text.count)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[TTS][Error] Failed to encode request body: \(error)")
            completion?(false)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("[TTS][Error] Request failed: \(error)")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("[TTS][Error] No HTTPURLResponse")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "<none>"
            print("[TTS] Response status=\(http.statusCode) content-type=\(contentType) bytes=\(data?.count ?? 0)")

            guard http.statusCode == 200, let data = data, !data.isEmpty else {
                if let data = data, let message = String(data: data, encoding: .utf8) {
                    print("[TTS][Error] API error (status: \(http.statusCode)): \(message)")
                } else {
                    print("[TTS][Error] API error (status: \(http.statusCode)) with no body")
                }
                DispatchQueue.main.async { completion?(false) }
                return
            }

            DispatchQueue.main.async {
                self?.playAudio(data: data, completion: completion)
            }
        }.resume()
    }
             
    private func playAudio(data: Data, completion: ((Bool) -> Void)? = nil) {
        do {
            audioPlayer?.stop(); audioPlayer = nil
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            let ok = audioPlayer?.play() ?? false
            print("[TTS] AVAudioPlayer started=\(ok) duration=\(audioPlayer?.duration ?? 0)s isPlaying=\(audioPlayer?.isPlaying ?? false)")
            Self.logAudioSessionRoute(prefix: "[TTS] Playback route")
            completion?(ok)
        } catch {
            print("[TTS][Error] Failed to play audio: \(error)")
            completion?(false)
        }
    }

    private static func logAudioSessionRoute(prefix: String) {
        let session = AVAudioSession.sharedInstance()
        let outs = session.currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
        print("\(prefix). Category=\(session.category.rawValue) Mode=\(session.mode.rawValue) RouteOuts=[\(outs)]")
    }

    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
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



