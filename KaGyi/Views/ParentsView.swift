import SwiftUI

/// Simple adult gate: a multiplication question kids can't easily answer.
struct ParentGate: View {
    let onPass: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var a = Int.random(in: 4...9)
    @State private var b = Int.random(in: 4...9)
    @State private var answer = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 18) {
            Text("For grown-ups").font(Theme.title(24))
            Text("What is \(a) × \(b)?").font(Theme.body(22))
            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.title(28))
                .frame(maxWidth: 160)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.12)))
            if wrong { Text("Not quite — try again").foregroundColor(.red) }
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(KidButtonStyle(color: .gray))
                Button("Continue") {
                    if Int(answer) == a * b { onPass() } else {
                        wrong = true; answer = ""
                        a = Int.random(in: 4...9); b = Int.random(in: 4...9)
                    }
                }
                .buttonStyle(KidButtonStyle(color: Theme.primary))
            }
        }
        .padding(24)
    }
}

struct ParentsView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(AppModel.Keys.difficulty) private var difficulty = Difficulty.normal.rawValue
    @AppStorage(AppModel.Keys.soundOn) private var soundOn = true
    @AppStorage(AppModel.Keys.guideOn) private var guideOn = true
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                Picker("Checking", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Difficulty")
            } footer: {
                Text("Easy gives stars for rougher letters. Hard needs neater writing.")
            }

            Section("Options") {
                Toggle("Letter sounds", isOn: $soundOn)
                Toggle("Show tracing guide", isOn: $guideOn)
            }

            Section("Progress") {
                LabeledContent("Stars collected", value: "\(model.totalStars)")
                Button("Reset all progress", role: .destructive) { confirmReset = true }
            }

            Section("About") {
                Text("KaGyi helps children learn to write the 33 Myanmar consonants. Handwriting is checked entirely on this device — drawings are never uploaded, and the app has no ads, accounts or tracking.")
                    .font(.footnote)
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
            }
        }
        .navigationTitle("Parents' Corner")
        .confirmationDialog("Reset all stars?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetProgress() }
        }
    }
}
