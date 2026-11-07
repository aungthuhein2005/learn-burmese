import SwiftUI

// MARK: Letter Grid (Practice entry)

struct LetterGridView: View {
    @EnvironmentObject var model: AppModel
    @Binding var path: [Route]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(Alphabet.grouped().enumerated()), id: \.offset) { g, group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(group.name) group")
                            .font(Theme.body(16)).foregroundColor(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(group.letters) { letter in
                                Button { path.append(.practice(letter.index)) } label: {
                                    VStack(spacing: 2) {
                                        Text(letter.char).font(.system(size: 34, weight: .semibold))
                                            .foregroundColor(Theme.ink)
                                        Text(letter.roman).font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                        StarsRow(count: model.stars(for: letter), size: 9)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 84)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.groupColors[g]))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(letter.roman), \(model.stars(for: letter)) stars")
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Practice")
    }
}

// MARK: Learn Cards

struct LearnView: View {
    @EnvironmentObject var model: AppModel
    @State private var index: Int
    @Binding var path: [Route]

    init(startIndex: Int, path: Binding<[Route]>) {
        _index = State(initialValue: startIndex)
        _path = path
    }

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $index) {
                ForEach(Alphabet.letters) { letter in
                    VStack(spacing: 12) {
                        Text(letter.char)
                            .font(.system(size: 180, weight: .bold))
                            .foregroundColor(Theme.ink)
                            .minimumScaleFactor(0.5)
                        Text(letter.roman).font(Theme.title(34)).foregroundColor(Theme.primary)
                        Text("\(Alphabet.groupNames[letter.group]) group · \(letter.index + 1) / \(Alphabet.letters.count)")
                            .font(Theme.body(14)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 32).fill(Theme.groupColors[letter.group]))
                    .padding(.horizontal, 4)
                    .tag(letter.index)
                    .onTapGesture { model.play(letter) }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                Button { model.play(Alphabet.letters[index]) } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(KidButtonStyle(color: Theme.accent))
                Button { path.append(.practice(index)) } label: {
                    Label("Write it", systemImage: "pencil.tip")
                }
                .buttonStyle(KidButtonStyle(color: Theme.primary))
            }
        }
        .padding(20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Learn")
        .onAppear { model.play(Alphabet.letters[index]) }
        .onChange(of: index) { newValue in model.play(Alphabet.letters[newValue]) }
    }
}

// MARK: My Stars

struct StarsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var path: [Route]

    private var mastered: Int { Alphabet.letters.filter { model.stars(for: $0) == 3 }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    statCard(value: "\(model.totalStars)", label: "Stars", symbol: "star.fill", color: Theme.star)
                    statCard(value: "\(mastered)/\(Alphabet.letters.count)", label: "Mastered", symbol: "crown.fill", color: Theme.success)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(Alphabet.letters) { letter in
                        let stars = model.stars(for: letter)
                        Button { path.append(.practice(letter.index)) } label: {
                            VStack(spacing: 4) {
                                Text(letter.char).font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(stars == 3 ? .white : Theme.ink)
                                StarsRow(count: stars, size: 9)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(stars == 3 ? Theme.success : Color.white))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("My Stars")
    }

    private func statCard(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundColor(color)
            Text(value).font(Theme.title(28)).foregroundColor(Theme.ink)
            Text(label).font(Theme.body(14)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
    }
}
