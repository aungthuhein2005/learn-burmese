import SwiftUI

/// Hear a letter, tap it among 4 choices. No writing needed, for younger children.
struct FindLetterView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    static let rounds = 10
    @State private var targets: [Letter] = []
    @State private var choices: [Letter] = []
    @State private var round = 0
    @State private var score = 0
    @State private var wrongPicks: Set<Int> = []
    @State private var solved = false
    @State private var finished = false

    private var target: Letter? { targets.indices.contains(round) ? targets[round] : nil }

    var body: some View {
        Group {
            if finished { summary } else { game }
        }
        .padding(20)
        .frame(maxWidth: Theme.maxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Find")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if targets.isEmpty { start() } }
    }

    private var game: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(round + 1) / \(Self.rounds)").font(Theme.body(18)).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundColor(Theme.star)
                    Text("\(score)").font(Theme.body(18)).foregroundColor(Theme.ink)
                }
            }

            Button { if let target { model.play(target) } } label: {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 44 * Theme.s, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 110 * Theme.s, height: 110 * Theme.s)
                        .background(Circle().fill(Theme.accent))
                        .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 4)
                    Text("Which letter is it?").font(Theme.title(22)).foregroundColor(Theme.ink)
                    Text("ဘယ်စာလုံးလဲ?").font(Theme.body(16)).foregroundColor(.secondary).myanmarSpacing()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Listen again")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(choices) { letter in
                    choiceButton(letter)
                }
            }

            if solved {
                Button(action: next) {
                    Label(round + 1 >= Self.rounds ? "Finish" : "Next", systemImage: "arrow.right")
                }
                .buttonStyle(KidButtonStyle(color: Theme.primary))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func choiceButton(_ letter: Letter) -> some View {
        let isTarget = letter == target
        let isWrong = wrongPicks.contains(letter.index)
        let fill: Color = solved && isTarget ? Theme.success : (isWrong ? Color.gray.opacity(0.25) : Color.white)
        return Button { pick(letter) } label: {
            Text(letter.char)
                .font(.system(size: 64 * Theme.s, weight: .semibold))
                .foregroundColor(solved && isTarget ? .white : (isWrong ? .gray : Theme.ink))
                .frame(maxWidth: .infinity, minHeight: 120 * Theme.s)
                .background(RoundedRectangle(cornerRadius: 24).fill(fill))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                .scaleEffect(solved && isTarget ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .disabled(solved || isWrong)
        .accessibilityLabel(letter.roman)
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🐘").font(.system(size: 90 * Theme.s))
            Text("\(score) / \(Self.rounds)").font(Theme.title(34)).foregroundColor(Theme.ink)
            Text(score >= 8 ? "သိပ်ကောင်းတယ်!" : "ကောင်းတယ်! ထပ်ကစားကြမယ်")
                .font(.system(size: 22 * Theme.s, weight: .bold)).foregroundColor(.secondary)
                .myanmarSpacing(6)
            Spacer()
            Button(action: start) { Label("Play again", systemImage: "arrow.counterclockwise") }
                .buttonStyle(KidButtonStyle(color: Theme.primary))
            Button { dismiss() } label: { Label("Home", systemImage: "house.fill") }
                .buttonStyle(KidButtonStyle(color: Theme.accent))
        }
    }

    // MARK: Game logic

    private func start() {
        targets = model.pickLetters(count: Self.rounds)
        round = 0
        score = 0
        finished = false
        setUpRound()
    }

    private func setUpRound() {
        guard let target else { return }
        wrongPicks = []
        solved = false
        // One distractor from the same row (looks/sounds closer), the rest random.
        let sameGroup = Alphabet.letters.filter { $0.group == target.group && $0 != target }.shuffled()
        var others = Array(sameGroup.prefix(1))
        let rest = Alphabet.letters.filter { $0 != target && !others.contains($0) }.shuffled()
        others += rest.prefix(3 - others.count)
        choices = (others + [target]).shuffled()
        model.play(target)
    }

    private func pick(_ letter: Letter) {
        guard let target, !solved else { return }
        if letter == target {
            // Full star only on the first try.
            let firstTry = wrongPicks.isEmpty
            if firstTry { score += 1 }
            model.recordFind(target, correct: firstTry)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { solved = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            model.playPraise(stars: firstTry ? 3 : 2)
        } else {
            withAnimation(.easeOut(duration: 0.2)) { _ = wrongPicks.insert(letter.index) }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            model.play(target)   // hear it again
        }
    }

    private func next() {
        if round + 1 >= Self.rounds {
            finished = true
        } else {
            round += 1
            setUpRound()
        }
    }
}
