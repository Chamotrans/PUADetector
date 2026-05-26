import SwiftUI

struct ScoreTrendView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let points = normalisedPoints(in: geo.size)
            ZStack(alignment: .bottomLeading) {
                baseline(y: geo.size.height * 0.62, width: geo.size.width, color: Palette.warning.opacity(0.45))
                baseline(y: geo.size.height * 0.32, width: geo.size.width, color: Palette.danger.opacity(0.50))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Palette.tiffany, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Palette.tiffany)
                        .frame(width: 4, height: 4)
                        .position(point)
                }
            }
        }
        .frame(height: 54)
        .accessibilityLabel("分數趨勢")
    }

    private func baseline(y: CGFloat, width: CGFloat, color: Color) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func normalisedPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let span = max(1, values.count - 1)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(span) * size.width
            let clamped = min(max(value, GaugeView.minValue), GaugeView.maxValue)
            let pct = (clamped - GaugeView.minValue) / (GaugeView.maxValue - GaugeView.minValue)
            let y = size.height - CGFloat(pct) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    ScoreTrendView(values: [20, 22, 28, 40, 78, 94, 88, 63, 42, 28])
        .padding()
        .background(Palette.background)
}
