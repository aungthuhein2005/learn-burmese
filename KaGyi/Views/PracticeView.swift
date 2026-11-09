import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(AppModel.Keys.guideOn) private var guideOn = true

    @State private var index: Int
    @State private var strokes: [[CGPoint]] = []
    @State private var checking = false
    @State private var result: IdentifiedResult?

    init(startIndex: Int) {
        _index = State(initialValue: startIndex)
    }

    private var letter: Letter { Alphabet.letters[index] }

    var body: some View {
        VStack(spacing: 16) {
            header

            DrawingCanvas(strokes: $strokes, guide: guideOn ? letter.char : nil)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                iconButton("chevron.left", label: "Previous") { move(-1) }
                    .disabled(index == 0)
                iconButton("arrow.uturn.backward", label: "Clear") { strokes = [] }
                iconButton(guideOn ? "eye.fill" : "eye.slash", label: "Guide") { guideOn.toggle() }
                iconButton("chevron.right", label: "Next") { move(1) }
                    .disabled(index == Alphabet.letters.count - 1)
            }

            Button {
                Task { await check() }
            } label: {
                HStack {
                    if checking { ProgressView().tint(.white) } else { Image(systemName: "checkmark.circle.fill") }
                    Text("Check  ·  စစ်မယ်").myanmarSpacing(2)
                }
            }
            .buttonStyle(KidButtonStyle(color: Theme.success))
            .disabled(strokes.isEmpty || checking)
            .opacity(strokes.isEmpty ? 0.5 : 1)
        }
        .padding(20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.play(letter)
            // Screenshot automation: `-demoDraw YES` writes the letter and checks it.
            if AppModel.isDemo, UserDefaults.standard.bool(forKey: "demoDraw"), strokes.isEmpty {
                let side = min(UIScreen.main.bounds.width, 640) - 48
                strokes = ImageNormalizer.demoStrokes(for: letter.char, canvasSide: side)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { Task { await check() } }
            }
        }
        .sheet(item: $result) { r in
            ResultSheet(result: r.result,
                        onAgain: { result = nil; strokes = [] },
                        onNext: nextAction)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(letter.char)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(Theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(letter.roman).font(Theme.title(26)).foregroundColor(Theme.ink)
                StarsRow(count: model.stars(for: letter), size: 18)
            }
            Spacer()
            Button { model.play(letter) } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.accent))
            }
            .accessibilityLabel("Listen")
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 22, weight: .bold))
                Text(label).font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    private var nextAction: (() -> Void)? {
        guard index < Alphabet.letters.count - 1 else { return nil }
        return {
            result = nil
            move(1)
        }
    }

    private func move(_ delta: Int) {
        let next = index + delta
        guard Alphabet.letters.indices.contains(next) else { return }
        index = next
        strokes = []
        model.play(letter)
    }

    private func check() async {
        guard let recognizer = model.recognizer else { return }
        checking = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let r = await recognizer.score(strokes: strokes, target: letter, difficulty: model.difficulty)
        checking = false
        if let r {
            model.record(r)
            model.playPraise(stars: r.stars)
            result = IdentifiedResult(result: r)
        }
    }
}

struct IdentifiedResult: Identifiable {
    let id = UUID()
    let result: ScoreResult
}
