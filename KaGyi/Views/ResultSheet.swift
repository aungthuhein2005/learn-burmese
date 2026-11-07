import SwiftUI

struct ResultSheet: View {
    let result: ScoreResult
    let onAgain: () -> Void
    let onNext: (() -> Void)?
    @State private var shown = 0

    private var message: (my: String, en: String) {
        switch result.stars {
        case 3: return ("သိပ်ကောင်းတယ်!", "Great job!")
        case 2: return ("ကောင်းတယ်!", "Good!")
        case 1: return ("နီးစပ်တယ်၊ ထပ်ကြိုးစားပါ", "Almost! Try again")
        default:
            if let other = result.lookalike {
                return ("ဒါ \(other.char) နဲ့ တူနေတယ်", "That looks like \(other.char) (\(other.roman))")
            }
            return ("ထပ်ရေးကြည့်ပါ", "Let's try again")
        }
    }

    var body: some View {
        ZStack {
            if result.stars == 3 { ConfettiView() }
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < result.stars ? "star.fill" : "star")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(i < result.stars ? Theme.star : .gray.opacity(0.3))
                            .scaleEffect(i < shown ? 1 : 0.3)
                            .opacity(i < result.stars ? (i < shown ? 1 : 0) : 1)
                    }
                }
                Text(message.my).font(.system(size: 24, weight: .bold)).foregroundColor(Theme.ink)
                Text(message.en).font(Theme.body(18)).foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: onAgain) {
                        Label("Again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(KidButtonStyle(color: Theme.accent))
                    if let onNext {
                        Button(action: onNext) {
                            Label("Next", systemImage: "arrow.right")
                        }
                        .buttonStyle(KidButtonStyle(color: Theme.primary))
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            for i in 0..<result.stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(i) * 0.25) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { shown = i + 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            if result.stars == 3 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

struct ConfettiView: View {
    @State private var fall = false
    private let pieces: [(x: CGFloat, delay: Double, color: Color, size: CGFloat)] = (0..<40).map { _ in
        (x: CGFloat.random(in: 0...1), delay: Double.random(in: 0...0.6),
         color: [Theme.primary, Theme.star, Theme.success, Theme.accent, Color(hex: 0xA77BFF)].randomElement()!,
         size: CGFloat.random(in: 6...12))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(fall ? Double(i * 47) : 0))
                    .position(x: p.x * geo.size.width, y: fall ? geo.size.height + 20 : -20)
                    .animation(.easeIn(duration: 1.6).delay(p.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fall = true }
    }
}
