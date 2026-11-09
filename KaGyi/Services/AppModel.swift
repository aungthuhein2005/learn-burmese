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
        loadProgress()
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

    @Published private(set) var lastStars: [Int: Int] = [:]   // letter index → most recent stars
    @Published private(set) var lifetimeStars = 0              // every star ever earned
    @Published private(set) var practiceDays: Set<String> = []
    /// Set when a sticker unlocks; the home screen shows a celebration and clears it.
    @Published var newSticker: Sticker?

    var totalStars: Int { bestStars.values.reduce(0, +) }
    var streak: Int { Rewards.streak(practiceDays: practiceDays) }
    var unlockedStickers: [Sticker] { Rewards.unlocked(lifetimeStars: lifetimeStars) }

    func stars(for letter: Letter) -> Int { bestStars[letter.index] ?? 0 }

    /// Records a writing result (Practice or Quiz).
    func record(_ result: ScoreResult) {
        let i = result.target.index
        lastStars[i] = result.stars
        if result.stars > (bestStars[i] ?? 0) { bestStars[i] = result.stars }
        earn(result.stars)
    }

    /// Records a Find-the-Letter answer: a correct tap earns one star.
    func recordFind(_ letter: Letter, correct: Bool) {
        earn(correct ? 1 : 0)
    }

    private func earn(_ stars: Int) {
        let before = Rewards.unlocked(lifetimeStars: lifetimeStars).count
        lifetimeStars += stars
        practiceDays.insert(Rewards.dayKey())
        let unlocked = Rewards.unlocked(lifetimeStars: lifetimeStars)
        if unlocked.count > before { newSticker = unlocked.last }
        save()
    }

    /// Letters for a quiz or game, favouring ones the child got wrong recently.
    func pickLetters(count: Int) -> [Letter] {
        Rewards.pickLetters(count: count, lastStars: lastStars)
    }

    func resetProgress() {
        bestStars = [:]
        lastStars = [:]
        lifetimeStars = 0
        practiceDays = []
        save()
    }

    private static func encode(_ d: [Int: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: d.map { (String($0.key), $0.value) })
    }

    private static func decode(_ any: Any?) -> [Int: Int] {
        guard let d = any as? [String: Int] else { return [:] }
        return Dictionary(uniqueKeysWithValues: d.compactMap { k, v in Int(k).map { ($0, v) } })
    }

    private func loadProgress() {
        let ud = UserDefaults.standard
        bestStars = Self.decode(ud.dictionary(forKey: starsKey))
        lastStars = Self.decode(ud.dictionary(forKey: "lastStars"))
        lifetimeStars = ud.integer(forKey: "lifetimeStars")
        practiceDays = Set(ud.stringArray(forKey: "practiceDays") ?? [])
        // Existing players keep credit for the stars they already earned.
        if lifetimeStars < totalStars { lifetimeStars = totalStars }
    }

    private func save() {
        let ud = UserDefaults.standard
        ud.set(Self.encode(bestStars), forKey: starsKey)
        ud.set(Self.encode(lastStars), forKey: "lastStars")
        ud.set(lifetimeStars, forKey: "lifetimeStars")
        ud.set(Array(practiceDays.sorted().suffix(400)), forKey: "practiceDays")
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
