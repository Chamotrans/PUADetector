import SwiftUI

struct RadarRippleView: View {
    var active: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height)
                let maxR = min(size.width, size.height * 2) * 0.55

                for i in 0..<4 {
                    let progress = (CGFloat((t + Double(i) * 0.4).truncatingRemainder(dividingBy: 1.6)) / 1.6)
                    let radius = maxR * progress
                    let opacity = (1.0 - progress) * 0.85

                    var p = Path()
                    p.addArc(center: center,
                             radius: radius,
                             startAngle: .degrees(180),
                             endAngle: .degrees(360),
                             clockwise: false)

                    context.stroke(
                        p,
                        with: .color(Palette.danger.opacity(Double(opacity))),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
            }
        }
        .overlay(alignment: .center) {
            if !active {
                Text("待機中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.tiffanyDim)
            }
        }
    }
}

#Preview {
    RadarRippleView(active: true)
        .frame(height: 120)
        .background(Palette.background)
}
