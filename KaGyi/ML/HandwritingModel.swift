import Foundation
import OnnxRuntimeBindings

/// Wraps the ONNX embedding model: [N, 3, 224, 224] image → [N, 256] embedding.
final class HandwritingModel {
    static let embeddingSize = 256
    private let env: ORTEnv
    private let session: ORTSession

    init() throws {
        guard let path = Bundle.main.path(forResource: "model_fp16", ofType: "onnx") else {
            throw NSError(domain: "KaGyi", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "model_fp16.onnx missing from app bundle"])
        }
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        session = try ORTSession(env: env, modelPath: path, sessionOptions: options)
    }

    /// Runs one batch. `inputs` are planar float arrays from `ImageNormalizer.modelInput`.
    func embed(_ inputs: [[Float]]) throws -> [[Float]] {
        guard !inputs.isEmpty else { return [] }
        let side = ImageNormalizer.side
        var flat = [Float]()
        flat.reserveCapacity(inputs.count * 3 * side * side)
        for x in inputs { flat.append(contentsOf: x) }

        let data = flat.withUnsafeBufferPointer { NSMutableData(bytes: $0.baseAddress!, length: $0.count * MemoryLayout<Float>.size) }
        let shape: [NSNumber] = [NSNumber(value: inputs.count), 3, NSNumber(value: side), NSNumber(value: side)]
        let tensor = try ORTValue(tensorData: data, elementType: .float, shape: shape)
        let outputs = try session.run(withInputs: ["input": tensor], outputNames: ["embeddings"], runOptions: nil)
        guard let out = outputs["embeddings"] else { return [] }
        let outData = try out.tensorData() as Data

        let all: [Float] = outData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let d = Self.embeddingSize
        return (0..<inputs.count).map { i in Self.normalized(Array(all[i * d ..< (i + 1) * d])) }
    }

    static func normalized(_ v: [Float]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? v.map { $0 / norm } : v
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        var dot: Float = 0
        for i in 0..<min(a.count, b.count) { dot += a[i] * b[i] }
        return dot   // both are unit length
    }
}
