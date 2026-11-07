import SwiftUI

/// Square cream canvas the child draws on, with an optional faint guide letter.
struct DrawingCanvas: View {
    @Binding var strokes: [[CGPoint]]
    let guide: String?
    @State private var current: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.canvas)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

                // Dashed writing guide lines
                Path { p in
                    for f in [0.25, 0.5, 0.75] {
                        p.move(to: CGPoint(x: side * 0.06, y: side * f))
                        p.addLine(to: CGPoint(x: side * 0.94, y: side * f))
                    }
                }
                .stroke(Theme.accent.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))

                if let guide {
                    Text(guide)
                        .font(.system(size: side * 0.55))
                        .foregroundColor(Theme.ink.opacity(0.13))
                        .allowsHitTesting(false)
                }

                Canvas { ctx, _ in
                    let style = StrokeStyle(lineWidth: side * 0.045, lineCap: .round, lineJoin: .round)
                    for stroke in strokes + [current] where !stroke.isEmpty {
                        var path = Path()
                        path.move(to: stroke[0])
                        if stroke.count == 1 {
                            path.addLine(to: stroke[0])
                        } else {
                            for p in stroke.dropFirst() { path.addLine(to: p) }
                        }
                        ctx.stroke(path, with: .color(Theme.ink), style: style)
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let p = CGPoint(x: min(max(value.location.x, 0), side),
                                        y: min(max(value.location.y, 0), side))
                        current.append(p)
                    }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current) }
                        current = []
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Drawing area")
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
