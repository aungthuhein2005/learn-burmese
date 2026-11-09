import Foundation

/// A collectible sticker, unlocked when the child's lifetime stars reach `stars`.
struct Sticker: Identifiable, Hashable {
    let id: Int
    let emoji: String
    let name: String
    let stars: Int
}

enum Rewards {
    static let stickers: [Sticker] = [
        ("🐘", "Elephant", 5), ("🦁", "Lion", 15), ("🐯", "Tiger", 30), ("🐼", "Panda", 50),
        ("🦒", "Giraffe", 75), ("🐢", "Turtle", 100), ("🦋", "Butterfly", 140), ("🐬", "Dolphin", 190),
        ("🦚", "Peacock", 250), ("🚀", "Rocket", 320), ("🌈", "Rainbow", 400), ("👑", "Crown", 500),
    ].enumerated().map { i, s in Sticker(id: i, emoji: s.0, name: s.1, stars: s.2) }

    static func unlocked(lifetimeStars: Int) -> [Sticker] {
        stickers.filter { $0.stars <= lifetimeStars }
    }

    static func nextSticker(lifetimeStars: Int) -> Sticker? {
        stickers.first { $0.stars > lifetimeStars }
    }

    // MARK: Daily streak

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Consecutive practice days ending today (or yesterday, so the streak survives
    /// until the child practises later today).
    static func streak(practiceDays: Set<String>, today: Date = Date()) -> Int {
        let cal = Calendar(identifier: .gregorian)
        var day = today
        if !practiceDays.contains(dayKey(day)) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day),
                  practiceDays.contains(dayKey(y)) else { return 0 }
            day = y
        }
        var count = 0
        while practiceDays.contains(dayKey(day)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    // MARK: Adaptive letter picking

    /// Weight for how often a letter should come up: letters never tried or scored low
    /// recently are picked far more often than letters already mastered.
    static func weight(lastStars: Int?) -> Double {
        switch lastStars {
        case nil: return 3      // never tried
        case 0?: return 6
        case 1?: return 5
        case 2?: return 3
        default: return 1       // 3 stars
        }
    }

    /// Picks `count` distinct letters, weighted by `weight(lastStars:)`.
    static func pickLetters(count: Int, lastStars: [Int: Int]) -> [Letter] {
        var pool = Alphabet.letters
        var picked: [Letter] = []
        while picked.count < count, !pool.isEmpty {
            let weights = pool.map { weight(lastStars: lastStars[$0.index]) }
            var r = Double.random(in: 0..<weights.reduce(0, +))
            var chosen = pool.count - 1
            for (i, w) in weights.enumerated() {
                if r < w { chosen = i; break }
                r -= w
            }
            picked.append(pool.remove(at: chosen))
        }
        return picked
    }

    // MARK: Mascot

    static func mascotMessage(streak: Int, lifetimeStars: Int) -> (my: String, en: String) {
        if lifetimeStars == 0 { return ("စာရေးကြမယ်!", "Let's write some letters!") }
        if streak >= 3 { return ("\(streak) ရက် ဆက်တိုက်! တော်လိုက်တာ!", "\(streak) days in a row! Amazing!") }
        if streak >= 1 { return ("ဒီနေ့လည်း လေ့ကျင့်ကြမယ်!", "Let's practise again today!") }
        return ("ပြန်လာတာ ဝမ်းသာတယ်!", "Welcome back!")
    }
}
