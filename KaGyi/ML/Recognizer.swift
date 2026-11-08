import Foundation
import UIKit

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    /// (3★, 2★, 1★) cosine-similarity thresholds.
    /// Same-letter similarity is typically 0.7–0.85; the closest *other* letter ~0.5.
    var thresholds: (three: Float, two: Float, one: Float) {
        switch self {
        case .easy: return (0.52, 0.40, 0.30)
        case .normal: return (0.60, 0.45, 0.35)
        case .hard: return (0.68, 0.52, 0.40)
        }
    }
}

struct ScoreResult {
    let target: Letter
    let stars: Int
    let similarity: Float
    let rank: Int               // 1 = the model thinks it's the target letter
    let lookalike: Letter?      // set when the drawing clearly matches another letter
}

/// Holds the model plus reference embeddings for every letter and scores drawings.
final class Recognizer {
    private let model: HandwritingModel
    /// refs[letterIndex] = embeddings of that letter rendered in several fonts.
    private var refs: [[[Float]]] = []
    private let queue = DispatchQueue(label: "kagyi.recognizer", qos: .userInitiated)

    /// Bump when the reference fonts or image normalization change.
    private static let cacheVersion = 3   // 3: pen-style references

    init() throws {
        model = try HandwritingModel()
    }

    /// Fonts used to build references. Missing fonts are skipped.
    private static func referenceFonts() -> [UIFont] {
        let names = ["MyanmarSangamMN", "NotoSansMyanmar-Regular"]
        var fonts = names.compactMap { UIFont(name: $0, size: 300) }
        if fonts.isEmpty { fonts = [UIFont.systemFont(ofSize: 300)] }
        return fonts
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // Keyed by the model file size, not the build number, so app updates keep the cache.
        let modelPath = Bundle.main.path(forResource: "model", ofType: "onnx") ?? ""
        let size = (try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? NSNumber)?.int64Value ?? 0
        return dir.appendingPathComponent("references_v\(cacheVersion)_\(size).json")
    }

    /// Loads cached references or computes them (first launch). Calls `progress` with 0...1.
    func prepare(progress: @escaping @Sendable (Double) -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    if let data = try? Data(contentsOf: Self.cacheURL),
                       let cached = try? JSONDecoder().decode([[[Float]]].self, from: data),
                       cached.count == Alphabet.letters.count {
                        self.refs = cached
                        print("KaGyi: loaded cached references")
                    } else {
                        let start = Date()
                        let fonts = Self.referenceFonts()
                        var result: [[[Float]]] = []
                        for (i, letter) in Alphabet.letters.enumerated() {
                            let inputs = fonts.compactMap { font in
                                ImageNormalizer.alpha(fromGlyph: letter.char, font: font)
                                    .flatMap(ImageNormalizer.penStyle)
                                    .map(ImageNormalizer.modelInput(fromAlpha:))
                            }
                            result.append(try self.model.embed(inputs))
                            progress(Double(i + 1) / Double(Alphabet.letters.count))
                        }
                        self.refs = result
                        print(String(format: "KaGyi: references ready in %.1fs (%d fonts)",
                                     Date().timeIntervalSince(start), fonts.count))
                        if let data = try? JSONEncoder().encode(result) {
                            try? data.write(to: Self.cacheURL, options: .atomic)
                        }
                    }
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func score(strokes: [[CGPoint]], target: Letter, difficulty: Difficulty) async -> ScoreResult? {
        await withCheckedContinuation { (cont: CheckedContinuation<ScoreResult?, Never>) in
            queue.async {
                cont.resume(returning: self.scoreSync(strokes: strokes, target: target, difficulty: difficulty))
            }
        }
    }

    private func scoreSync(strokes: [[CGPoint]], target: Letter, difficulty: Difficulty) -> ScoreResult? {
        guard refs.count == Alphabet.letters.count,
              let alpha = ImageNormalizer.alpha(fromStrokes: strokes),
              let emb = try? model.embed([ImageNormalizer.modelInput(fromAlpha: alpha)]).first
        else { return nil }

        // Best similarity per letter across its reference fonts.
        let sims: [Float] = refs.map { letterRefs in
            letterRefs.map { HandwritingModel.cosine(emb, $0) }.max() ?? -1
        }
        let targetSim = sims[target.index]
        let rank = 1 + sims.filter { $0 > targetSim }.count
        let t = difficulty.thresholds

        let stars: Int
        if rank == 1 && targetSim >= t.three {
            stars = 3
        } else if rank <= 3 && targetSim >= t.two {
            stars = 2
        } else if targetSim >= t.one {
            stars = 1
        } else {
            stars = 0
        }

        var lookalike: Letter?
        if stars <= 1, let best = sims.indices.max(by: { sims[$0] < sims[$1] }),
           best != target.index, sims[best] >= t.three {
            lookalike = Alphabet.letters[best]
        }
        return ScoreResult(target: target, stars: stars, similarity: targetSim, rank: rank, lookalike: lookalike)
    }
}
