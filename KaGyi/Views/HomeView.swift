import SwiftUI

struct LoadingView: View {
    let progress: Double
    let error: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Akkhara")
                .font(Theme.title(48))
                .foregroundColor(Theme.primary)
            if let error {
                Text("Something went wrong").font(Theme.body())
                Text(error).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
            } else {
                ProgressView(value: progress)
                    .tint(Theme.primary)
                    .frame(maxWidth: 260)
                Text("Getting the letters ready…").font(Theme.body(16)).foregroundColor(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

enum Route: Hashable {
    case grid, learn(Int), practice(Int), quiz, find, stars, stickers, parents
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [Route] = []
    @State private var showGate = false
    @State private var didOpenLaunchRoute = false

    var body: some View {
        NavigationStack(path: $path) { content }
            .onAppear(perform: openLaunchRoute)
            .overlay {
                if let sticker = model.newSticker {
                    StickerCelebration(sticker: sticker) {
                        withAnimation { model.newSticker = nil }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: model.newSticker)
    }

    /// Screenshot automation: `-route find|quiz|stickers|stars|grid|learn:N|practice:N`.
    private func openLaunchRoute() {
        guard !didOpenLaunchRoute, AppModel.isDemo,
              let arg = UserDefaults.standard.string(forKey: "route") else { return }
        didOpenLaunchRoute = true
        let parts = arg.split(separator: ":")
        let n = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let route: Route?
        switch parts.first {
        case "find": route = .find
        case "quiz": route = .quiz
        case "stickers": route = .stickers
        case "stars": route = .stars
        case "grid": route = .grid
        case "learn": route = .learn(n)
        case "practice": route = .practice(n)
        default: route = nil
        }
        if let route { path = [route] }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Akkhara").font(Theme.title(44)).foregroundColor(Theme.primary)
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").foregroundColor(Theme.star)
                            Text("\(model.lifetimeStars)").font(Theme.body(18)).foregroundColor(Theme.ink)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundColor(model.streak > 0 ? Theme.primary : .gray)
                            Text(model.streak == 1 ? "1 day" : "\(model.streak) days").font(Theme.body(18)).foregroundColor(Theme.ink)
                        }
                    }
                    .padding(.top, 4)
                    .accessibilityElement(children: .combine)
                }
                .padding(.top, 8)

                MascotBubble(message: Rewards.mascotMessage(streak: model.streak, lifetimeStars: model.lifetimeStars))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    HomeTile(symbol: "book.fill", title: "Learn", subtitle: "လေ့လာမယ်", color: Theme.accent) {
                        path.append(.learn(0))
                    }
                    HomeTile(symbol: "pencil.tip", title: "Practice", subtitle: "ရေးကြည့်မယ်", color: Theme.primary) {
                        path.append(.grid)
                    }
                    HomeTile(symbol: "hand.tap.fill", title: "Find", subtitle: "ရှာကြည့်မယ်", color: Color(hex: 0xFF5C8A)) {
                        path.append(.find)
                    }
                    HomeTile(symbol: "target", title: "Quiz", subtitle: "စစ်ကြည့်မယ်", color: Color(hex: 0xA77BFF)) {
                        path.append(.quiz)
                    }
                    HomeTile(symbol: "star.fill", title: "My Stars", subtitle: "ကြယ်တွေ", color: Theme.success) {
                        path.append(.stars)
                    }
                    HomeTile(symbol: "face.smiling.inverse", title: "Stickers",
                             subtitle: "\(model.unlockedStickers.count) / \(Rewards.stickers.count)",
                             color: Color(hex: 0x2BB5C4)) {
                        path.append(.stickers)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showGate = true } label: {
                    Image(systemName: "lock.fill").foregroundColor(.gray)
                }
                .accessibilityLabel("Parents' corner")
            }
        }
        .sheet(isPresented: $showGate) {
            ParentGate { showGate = false; path.append(.parents) }
                .presentationDetents([.medium])
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .grid: LetterGridView(path: $path)
            case .learn(let i): LearnView(startIndex: i, path: $path)
            case .practice(let i): PracticeView(startIndex: i)
            case .quiz: QuizView()
            case .find: FindLetterView()
            case .stars: StarsView(path: $path)
            case .stickers: StickersView()
            case .parents: ParentsView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeTile: View {
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 40, weight: .bold))
                Text(title).font(Theme.title(22))
                Text(subtitle).font(.system(size: 15, weight: .medium)).opacity(0.9).myanmarSpacing()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(RoundedRectangle(cornerRadius: 28).fill(color))
            .shadow(color: color.opacity(0.35), radius: 8, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The elephant mascot with a speech bubble on the home screen.
struct MascotBubble: View {
    let message: (my: String, en: String)
    @State private var bounce = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("🐘")
                .font(.system(size: 54))
                .offset(y: bounce ? -4 : 2)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: bounce)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.my).font(.system(size: 17, weight: .bold)).foregroundColor(Theme.ink)
                    .myanmarSpacing(2)
                Text(message.en).font(Theme.body(14)).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        .onAppear { bounce = true }
        .accessibilityElement(children: .combine)
    }
}
