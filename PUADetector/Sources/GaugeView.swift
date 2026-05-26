import SwiftUI

struct GaugeView: View {
    static let minValue: Double = 20
    static let maxValue: Double = 130
    static let startAngle: Double = 150
    static let endAngle: Double = 30

    var value: Double
    var minRange: Double
    var maxRange: Double
    var minMarker: Double
    var peakMarker: Double

    private var clamped: Double {
        min(max(value, minRange), maxRange)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height * 2)
            let radius = size / 2 - 16
            let center = CGPoint(x: geo.size.width / 2, y: radius + 16)

            ZStack {
                ArcShape(startAngle: GaugeView.startAngle,
                         endAngle: GaugeView.endAngle)
                    .stroke(Palette.tiffanyDim.opacity(0.35),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))

                ArcShape(startAngle: GaugeView.startAngle,
                         endAngle: angle(for: clamped))
                    .stroke(
                        AngularGradient(colors: [Palette.tiffany, .yellow, Palette.danger],
                                        center: .center,
                                        startAngle: .degrees(GaugeView.startAngle),
                                        endAngle: .degrees(GaugeView.endAngle + 360)),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .animation(.easeOut(duration: 0.4), value: clamped)

                TickMarks(min: minRange, max: maxRange, center: center, radius: radius)

                MarkerLabel(text: "MIN", value: Int(minMarker),
                            color: Palette.tiffany,
                            center: center, radius: radius - 38,
                            angle: angle(for: minMarker))

                MarkerLabel(text: "PEAK", value: Int(peakMarker),
                            color: Palette.danger,
                            center: center, radius: radius - 38,
                            angle: angle(for: peakMarker))

                Needle(angle: angle(for: clamped))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: clamped)

                Circle()
                    .fill(Palette.tiffany)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                    .position(center)

                Text(String(format: "%.0f", clamped))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .position(x: center.x, y: center.y + 60)
            }
        }
    }

    private func angle(for v: Double) -> Double {
        let pct = (min(max(v, minRange), maxRange) - minRange) / (maxRange - minRange)
        // Sweep from 150° clockwise to 390° (i.e. 30°)
        return GaugeView.startAngle + pct * 240
    }
}

private struct ArcShape: Shape {
    var startAngle: Double
    var endAngle: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius = min(rect.width, rect.height * 2) / 2 - 16
        let center = CGPoint(x: rect.midX, y: radius + 16)
        // Normalize so end is always > start in the sweep direction
        let end = endAngle < startAngle ? endAngle + 360 : endAngle
        p.addArc(center: center,
                 radius: radius,
                 startAngle: .degrees(startAngle),
                 endAngle: .degrees(end),
                 clockwise: false)
        return p
    }
}

private struct TickMarks: View {
    let min: Double
    let max: Double
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(stride(from: min, through: max, by: 10)), id: \.self) { v in
                let pct = (v - min) / (max - min)
                let angle = 150.0 + pct * 240.0
                let isMajor = Int(v) % 20 == 0
                TickLabel(value: Int(v), angle: angle,
                          center: center, radius: radius - 4,
                          major: isMajor)
            }
        }
    }
}

private struct TickLabel: View {
    let value: Int
    let angle: Double
    let center: CGPoint
    let radius: CGFloat
    let major: Bool

    var body: some View {
        let rad = angle * .pi / 180
        let labelRadius = radius - 22
        let x = center.x + cos(rad) * labelRadius
        let y = center.y + sin(rad) * labelRadius

        Text("\(value)")
            .font(.system(size: major ? 12 : 9, weight: major ? .bold : .regular))
            .foregroundColor(major ? Palette.tiffany : Palette.tiffanyDim)
            .position(x: x, y: y)
    }
}

private struct MarkerLabel: View {
    let text: String
    let value: Int
    let color: Color
    let center: CGPoint
    let radius: CGFloat
    let angle: Double

    var body: some View {
        let rad = angle * .pi / 180
        let x = center.x + cos(rad) * radius
        let y = center.y + sin(rad) * radius

        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 10, weight: .black))
            Text("\(value)")
                .font(.system(size: 13, weight: .heavy))
        }
        .foregroundColor(color)
        .position(x: x, y: y)
    }
}

private struct Needle: View {
    let angle: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w / 2, y: h / 2))
                p.addLine(to: CGPoint(x: w / 2 - 4, y: h / 2))
                p.addLine(to: CGPoint(x: w * 0.92, y: h / 2 - 2))
                p.addLine(to: CGPoint(x: w * 0.95, y: h / 2))
                p.addLine(to: CGPoint(x: w * 0.92, y: h / 2 + 2))
                p.addLine(to: CGPoint(x: w / 2 - 4, y: h / 2))
                p.closeSubpath()
            }
            .fill(Palette.danger)
            .shadow(color: Palette.danger.opacity(0.7), radius: 6)
            .rotationEffect(.degrees(angle), anchor: .center)
        }
    }
}
