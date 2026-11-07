import AVFoundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum LoadState: Equatable {
        case loading(Double)
        case ready
        case failed(String)
    }

    @Published var loadState: LoadState = .loading(0)
    @Published private(set) var bestStars: [Int: Int] = [:]   // letter index → best stars

    // Settings are edited in ParentsView via @AppStorage with these keys.
    enum Keys {
        static let difficulty = "difficulty"
        static let soundOn = "soundOn"
        static let guideOn = "guideOn"
    }

    var difficulty: Difficulty {
        Difficulty(rawValue: UserDefaults.standard.string(forKey: Keys.difficulty) ?? "") ?? .normal
    }
    var soundOn: Bool { UserDefaults.standard.object(forKey: Keys.soundOn) as? Bool ?? true }

    private(set) var recognizer: Recognizer?
    private var player: AVAudioPlayer?
    private let starsKey = "bestStars"

    init() {
        if let saved = UserDefaults.standard.dictionary(forKey: starsKey) as? [String: Int] {
            bestStars = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in Int(k).map { ($0, v) } })
        }
        // .playback so letter sounds play even when the Ring/Silent switch is on silent
        // (.ambient is muted by it). mixWithOthers keeps any music the child is playing.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func load() async {
        guard recognizer == nil else { return }
        do {
            let r = try Recognizer()
            try await r.prepare { p in
                Task { @MainActor in self.loadState = .loading(p) }
            }
            recognizer = r
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Progress

    var totalStars: Int { bestStars.values.reduce(0, +) }

    func stars(for letter: Letter) -> Int { bestStars[letter.index] ?? 0 }

    func record(_ result: ScoreResult) {
        let i = result.target.index
        guard result.stars > (bestStars[i] ?? 0) else { return }
        bestStars[i] = result.stars
        save()
    }

    func resetProgress() {
        bestStars = [:]
        save()
    }

    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: bestStars.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(dict, forKey: starsKey)
    }

    // MARK: Audio

    func play(_ letter: Letter) {
        playClip(letter.voiceFile)
    }

    /// Spoken encouragement after a check (praise_0 ... praise_3).
    func playPraise(stars: Int) {
        playClip("praise_\(min(max(stars, 0), 3))")
    }

    /// Plays a bundled clip; prefers the generated Azure .wav, falls back to the human .m4a recording.
    func playClip(_ name: String) {
        guard soundOn,
              let url = Bundle.main.url(forResource: name, withExtension: "wav")
                ?? Bundle.main.url(forResource: name, withExtension: "m4a")
        else {
            print("Missing audio clip: \(name)")
            return
        }
        player?.stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 1
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            print("Audio play error for \(name): \(error)")
        }
    }
}
