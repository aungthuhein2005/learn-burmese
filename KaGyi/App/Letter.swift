import Foundation

struct Letter: Identifiable, Hashable {
    let index: Int          // 0-based position in the alphabet
    let char: String
    let roman: String
    let group: Int          // 0...6, the traditional row (ဝဂ်)

    var id: Int { index }
    var voiceFile: String { String(format: "letter_%02d", index + 1) }
}

enum Alphabet {
    static let groupNames = ["က", "စ", "ဋ", "တ", "ပ", "ယ", "အ"]

    private static let raw: [(String, String, Int)] = [
        ("က", "ka", 0), ("ခ", "kha", 0), ("ဂ", "ga", 0), ("ဃ", "gha", 0), ("င", "nga", 0),
        ("စ", "sa", 1), ("ဆ", "hsa", 1), ("ဇ", "za", 1), ("ဈ", "zha", 1), ("ည", "nya", 1),
        ("ဋ", "ta", 2), ("ဌ", "hta", 2), ("ဍ", "da", 2), ("ဎ", "dha", 2), ("ဏ", "na", 2),
        ("တ", "ta", 3), ("ထ", "hta", 3), ("ဒ", "da", 3), ("ဓ", "dha", 3), ("န", "na", 3),
        ("ပ", "pa", 4), ("ဖ", "pha", 4), ("ဗ", "ba", 4), ("ဘ", "bha", 4), ("မ", "ma", 4),
        ("ယ", "ya", 5), ("ရ", "ra", 5), ("လ", "la", 5), ("ဝ", "wa", 5), ("သ", "tha", 5),
        ("ဟ", "ha", 6), ("ဠ", "la", 6), ("အ", "a", 6),
    ]

    static let letters: [Letter] = raw.enumerated().map { i, r in
        Letter(index: i, char: r.0, roman: r.1, group: r.2)
    }

    static func grouped() -> [(name: String, letters: [Letter])] {
        groupNames.enumerated().map { g, name in
            (name, letters.filter { $0.group == g })
        }
    }
}
