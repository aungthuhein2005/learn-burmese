import SwiftUI

struct StickersView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    stat(value: "\(model.lifetimeStars)", label: "Stars earned", symbol: "star.fill", color: Theme.star)
                    stat(value: "\(model.streak)", label: model.streak == 1 ? "Day streak" : "Days streak",
                         symbol: "flame.fill", color: Theme.primary)
                }

                if let next = Rewards.nextSticker(lifetimeStars: model.lifetimeStars) {
                    let prevGoal = Rewards.unlocked(lifetimeStars: model.lifetimeStars).last?.stars ?? 0
                    let progress = Double(model.lifetimeStars - prevGoal) / Double(max(next.stars - prevGoal, 1))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Next sticker").font(Theme.body(16)).foregroundColor(Theme.ink)
                            Spacer()
                            Text("\(next.stars - model.lifetimeStars) more ⭐").font(Theme.body(15)).foregroundColor(.secondary)
                        }
                        ProgressView(value: min(max(progress, 0), 1)).tint(Theme.primary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                } else {
                    Text("You collected every sticker! 👑").font(Theme.body(18)).foregroundColor(Theme.ink)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(Rewards.stickers) { sticker in
                        let unlocked = sticker.stars <= model.lifetimeStars
                        VStack(spacing: 6) {
                            Text(unlocked ? sticker.emoji : "🔒")
                                .font(.system(size: 52))
                                .grayscale(unlocked ? 0 : 1)
                                .opacity(unlocked ? 1 : 0.45)
                            Text(unlocked ? sticker.name : "\(sticker.stars) ⭐")
                                .font(Theme.body(13)).foregroundColor(unlocked ? Theme.ink : .secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .background(RoundedRectangle(cornerRadius: 20).fill(unlocked ? Color.white : Color.white.opacity(0.5)))
                        .accessibilityLabel(unlocked ? sticker.name : "Locked, needs \(sticker.stars) stars")
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stickers")
    }

    private func stat(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundColor(color)
            Text(value).font(Theme.title(28)).foregroundColor(Theme.ink)
            Text(label).font(Theme.body(14)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
    }
}

/// Full-screen "New sticker!" celebration.
struct StickerCelebration: View {
    let sticker: Sticker
    let onDone: () -> Void
    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onDone)
            ConfettiView()
            VStack(spacing: 14) {
                Text(sticker.emoji)
                    .font(.system(size: 120))
                    .scaleEffect(pop ? 1 : 0.2)
                    .rotationEffect(.degrees(pop ? 0 : -30))
                Text("New sticker!").font(Theme.title(30)).foregroundColor(Theme.ink)
                Text("စတစ်ကာ အသစ် ရပြီ!").font(.system(size: 20, weight: .bold)).foregroundColor(.secondary)
                    .myanmarSpacing(4)
                Text(sticker.name).font(Theme.body(18)).foregroundColor(Theme.primary)
                Button("Yay!", action: onDone)
                    .buttonStyle(KidButtonStyle(color: Theme.success))
                    .frame(maxWidth: 220)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 32).fill(Theme.canvas))
            .padding(32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
