import SwiftUI

/// 10 rounds: hear a letter, write it from memory (no guide).
struct QuizView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    static let rounds = 10
    @State private var questions: [Letter] = Array(Alphabet.letters.shuffled().prefix(QuizView.rounds))
    @State private var round = 0
    @State private var strokes: [[CGPoint]] = []
    @State private var checking = false
    @State private var lastStars: Int?
    @State private var earned = 0
    @State private var finished = false

    private var letter: Letter { questions[round] }

    var body: some View {
        Group {
            if finished { summary } else { question }
        }
        .padding(20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.play(letter) }
    }

    private var question: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(round + 1) / \(Self.rounds)").font(Theme.body(18)).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundColor(Theme.star)
                    Text("\(earned)").font(Theme.body(18))
                }
            }
            HStack(spacing: 14) {
                Button { model.play(letter) } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Theme.accent))
                }
                .accessibilityLabel("Listen again")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Listen and write!").font(Theme.title(22)).foregroundColor(Theme.ink)
                    Text("နားထောင်ပြီး ရေးပါ").font(Theme.body(16)).foregroundColor(.secondary)
                }
                Spacer()
            }

            ZStack(alignment: .top) {
                DrawingCanvas(strokes: $strokes, guide: nil)
                if let s = lastStars {
                    VStack(spacing: 4) {
                        StarsRow(count: s, size: 30)
                        Text(letter.char).font(.system(size: 40, weight: .bold)).foregroundColor(Theme.primary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.95)))
                    .padding(.top, 12)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if lastStars == nil {
                HStack(spacing: 12) {
                    Button { strokes = [] } label: { Label("Clear", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(KidButtonStyle(color: .gray))
                    Button { Task { await check() } } label: {
                        Label("Check", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(KidButtonStyle(color: Theme.success))
                    .disabled(strokes.isEmpty || checking)
                    .opacity(strokes.isEmpty ? 0.5 : 1)
                }
            } else {
                Button(action: next) { Label("Next", systemImage: "arrow.right") }
                    .buttonStyle(KidButtonStyle(color: Theme.primary))
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "trophy.fill").font(.system(size: 90)).foregroundColor(Theme.star)
            Text("\(earned) / \(Self.rounds * 3) stars").font(Theme.title(32)).foregroundColor(Theme.ink)
            Text(earned >= Self.rounds * 2 ? "သိပ်ကောင်းတယ်!" : "ကောင်းတယ်! ထပ်ကြိုးစားကြမယ်")
                .font(.system(size: 22, weight: .bold)).foregroundColor(.secondary)
            Spacer()
            Button {
                questions = Array(Alphabet.letters.shuffled().prefix(Self.rounds))
                round = 0; earned = 0; finished = false; strokes = []; lastStars = nil
                model.play(letter)
            } label: { Label("Play again", systemImage: "arrow.counterclockwise") }
                .buttonStyle(KidButtonStyle(color: Theme.primary))
            Button { dismiss() } label: { Label("Home", systemImage: "house.fill") }
                .buttonStyle(KidButtonStyle(color: Theme.accent))
        }
    }

    private func check() async {
        guard let recognizer = model.recognizer else { return }
        checking = true
        let r = await recognizer.score(strokes: strokes, target: letter, difficulty: model.difficulty)
        checking = false
        guard let r else { return }
        model.record(r)
        earned += r.stars
        withAnimation(.spring()) { lastStars = r.stars }
        if r.stars == 3 { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    private func next() {
        lastStars = nil
        strokes = []
        if round + 1 >= Self.rounds {
            finished = true
        } else {
            round += 1
            model.play(letter)
        }
    }
}
