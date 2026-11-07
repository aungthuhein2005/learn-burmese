import CoreGraphics
import UIKit

/// Turns a child's strokes or a font glyph into the model's input:
/// a 224×224 cream image with dark ink, cropped to the ink, centered and scaled
/// so that the longer side fills (1 - 2·margin) of the square.
/// Both paths produce the same framing, so drawing size/position doesn't matter.
enum ImageNormalizer {
    static let side = 224
    static let margin: CGFloat = 0.12
    /// Pen width in model pixels. Tuned so hand strokes look like font strokes.
    static let penWidth: CGFloat = 10

    private static let background: [Float] = [255, 252, 248]   // #FFFCF8
    private static let ink: [Float] = [61, 61, 61]             // #3D3D3D

    // MARK: Strokes

    /// `strokes` are in any coordinate space with y pointing down.
    static func alpha(fromStrokes strokes: [[CGPoint]]) -> [UInt8]? {
        let points = strokes.flatMap { $0 }
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let w = max(maxX - minX, 1), h = max(maxY - minY, 1)
        let size = CGFloat(side)
        let usable = size * (1 - 2 * margin) - penWidth
        let scale = usable / max(w, h)
        let offsetX = size / 2 - (minX + w / 2) * scale
        let offsetY = size / 2 - (minY + h / 2) * scale

        return render { ctx in
            // Flip so we can draw with y pointing down (row 0 = top of image).
            ctx.translateBy(x: 0, y: size)
            ctx.scaleBy(x: 1, y: -1)
            ctx.setStrokeColor(gray: 1, alpha: 1)
            ctx.setLineWidth(penWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for stroke in strokes where !stroke.isEmpty {
                let pts = stroke.map { CGPoint(x: $0.x * scale + offsetX, y: $0.y * scale + offsetY) }
                ctx.beginPath()
                ctx.move(to: pts[0])
                if pts.count == 1 {
                    ctx.addLine(to: pts[0])          // a tap becomes a dot
                } else {
                    for p in pts.dropFirst() { ctx.addLine(to: p) }
                }
                ctx.strokePath()
            }
        }
    }

    // MARK: Glyphs

    static func alpha(fromGlyph text: String, font: UIFont) -> [UInt8]? {
        let canvas: CGFloat = 600
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format).image { c in
            UIColor.black.setFill()
            c.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
            let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white])
            let b = str.size()
            str.draw(at: CGPoint(x: (canvas - b.width) / 2, y: (canvas - b.height) / 2))
        }
        guard let cg = image.cgImage,
              let pixels = grayPixels(of: cg) else { return nil }

        let wpx = cg.width, hpx = cg.height
        var minX = wpx, minY = hpx, maxX = -1, maxY = -1
        for y in 0..<hpx {
            for x in 0..<wpx where pixels[y * wpx + x] > 127 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let crop = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else { return nil }

        let size = CGFloat(side)
        let usable = size * (1 - 2 * margin)
        let scale = usable / CGFloat(max(crop.width, crop.height))
        let dw = CGFloat(crop.width) * scale, dh = CGFloat(crop.height) * scale
        return render { ctx in
            ctx.interpolationQuality = .high
            ctx.draw(crop, in: CGRect(x: (size - dw) / 2, y: (size - dh) / 2, width: dw, height: dh))
        }
    }

    // MARK: Model input

    /// Planar RGB float32 [3, 224, 224] in 0...1, ink blended over cream.
    static func modelInput(fromAlpha alpha: [UInt8]) -> [Float] {
        let n = side * side
        var out = [Float](repeating: 0, count: 3 * n)
        for i in 0..<n {
            let a = Float(alpha[i]) / 255
            for c in 0..<3 {
                out[c * n + i] = (background[c] * (1 - a) + ink[c] * a) / 255
            }
        }
        return out
    }

    // MARK: Helpers

    /// Renders into a 224×224 8-bit gray buffer (black = no ink, white = ink).
    private static func render(_ draw: (CGContext) -> Void) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: side * side)
        let ok: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: side,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.setFillColor(gray: 0, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            draw(ctx)
            return true
        }
        return ok ? buffer : nil
    }

    private static func grayPixels(of image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        var buffer = [UInt8](repeating: 0, count: w * h)
        let ok: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buffer : nil
    }
}
