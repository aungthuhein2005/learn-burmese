import SwiftUI

struct LoadingView: View {
    let progress: Double
    let error: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("ကကြီး")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(Theme.primary)
            Text("KaGyi").font(Theme.title(32)).foregroundColor(Theme.ink)
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
    case grid, learn(Int), practice(Int), quiz, stars, parents
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [Route] = []
    @State private var showGate = false

    var body: some View {
        NavigationStack(path: $path) { content }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("ကကြီး").font(.system(size: 56, weight: .bold)).foregroundColor(Theme.primary)
                    Text("KaGyi").font(Theme.title(26)).foregroundColor(Theme.ink)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundColor(Theme.star)
                        Text("\(model.totalStars) stars").font(Theme.body(18)).foregroundColor(Theme.ink)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    HomeTile(symbol: "book.fill", title: "Learn", subtitle: "လေ့လာမယ်", color: Theme.accent) {
                        path.append(.learn(0))
                    }
                    HomeTile(symbol: "pencil.tip", title: "Practice", subtitle: "ရေးကြည့်မယ်", color: Theme.primary) {
                        path.append(.grid)
                    }
                    HomeTile(symbol: "target", title: "Quiz", subtitle: "စစ်ကြည့်မယ်", color: Color(hex: 0xA77BFF)) {
                        path.append(.quiz)
                    }
                    HomeTile(symbol: "star.fill", title: "My Stars", subtitle: "ကြယ်တွေ", color: Theme.success) {
                        path.append(.stars)
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
            case .stars: StarsView(path: $path)
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
                Text(subtitle).font(.system(size: 15, weight: .medium)).opacity(0.9)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(RoundedRectangle(cornerRadius: 28).fill(color))
            .shadow(color: color.opacity(0.35), radius: 8, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
