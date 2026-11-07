import SwiftUI

enum Theme {
    static let canvas = Color(hex: 0xFFFCF8)     // must match the model's background
    static let ink = Color(hex: 0x3D3D3D)
    static let primary = Color(hex: 0xFF8A3D)
    static let success = Color(hex: 0x3DBE7A)
    static let accent = Color(hex: 0x4AA8FF)
    static let star = Color(hex: 0xFFC83D)
    static let background = Color(hex: 0xFFF4E6)

    static let groupColors: [Color] = [
        Color(hex: 0xFFE0CC), Color(hex: 0xD6F0FF), Color(hex: 0xE3F7DF), Color(hex: 0xFFF1C2),
        Color(hex: 0xF0E2FF), Color(hex: 0xFFDDE8), Color(hex: 0xDDF3F0),
    ]

    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Big rounded button used across the app (icon + word, ≥ 64 pt tall).
struct KidButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(20))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 22).fill(color))
            .shadow(color: color.opacity(0.35), radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct StarsRow: View {
    let count: Int
    var size: CGFloat = 14
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(i < count ? Theme.star : .gray.opacity(0.35))
            }
        }
        .accessibilityLabel("\(count) of 3 stars")
    }
}
