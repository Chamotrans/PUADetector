import SwiftUI

/// A simple view that analyses pasted/shared text and shows PUA detection results.
/// Used both by the Share Extension and as a manual text input in the main app.
struct TextAnalyzerView: View {
    let inputText: String
    let results: PUAClassifier.Result?
    let disabledCategories: Set<PUAClassifier.Category>

    @State private var highlightedText: AttributedString = ""
    @State private var showingFullText = false

    private let threshold: Double = 30  // High sensitivity

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(Palette.tiffany)
                    Text("文字 PUA 分析")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 12)

                if let results = results {
                    // Score gauge
                    HStack(spacing: 12) {
                        ScoreRingView(score: results.score, threshold: threshold)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(riskLevelText(for: results.score))
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(scoreColor(for: results.score))
                            Text(results.summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Palette.panel)
                    )

                    // Highlighted text
                    VStack(alignment: .leading, spacing: 8) {
                        Label("分析文字", systemImage: "text.alignleft")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Palette.tiffany)

                        Text(showingFullText ? inputText : String(inputText.prefix(300)))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)

                        if inputText.count > 300 {
                            Button(showingFullText ? "收合" : "顯示全部 (\(inputText.count) 字)") {
                                showingFullText.toggle()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Palette.tiffany)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Palette.panel.opacity(0.6))
                    )
                    .padding(.horizontal, 16)

                    // Hits list
                    if !results.hits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("偵測到 \(results.hits.count) 個潛在 PUA 語句",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Palette.warning)

                            ForEach(Array(results.hits.sorted { $0.weight > $1.weight }.prefix(10)), id: \.phrase) { hit in
                                HitRow(hit: hit)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Palette.panel.opacity(0.6))
                        )
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Palette.tiffany)
                            Text("未發現明顯 PUA 語句")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.vertical, 20)
                    }
                } else {
                    // Analysing
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Palette.tiffany)
                        Text("分析中...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func riskLevelText(for score: Double) -> String {
        if score >= 86 { return "⚠️ 高度風險" }
        if score >= 60 { return "⚡ 中度風險" }
        if score >= threshold { return "👀 輕微風險" }
        return "✅ 安全"
    }

    private func scoreColor(for score: Double) -> Color {
        if score >= 86 { return Palette.danger }
        if score >= 60 { return Palette.warning }
        if score >= threshold { return .orange }
        return Palette.tiffany
    }
}

struct ScoreRingView: View {
    let score: Double
    let threshold: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(score / 130.0, 1.0)))
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(score))")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private var scoreColor: Color {
        if score >= 86 { return Palette.danger }
        if score >= 60 { return Palette.warning }
        if score >= threshold { return .orange }
        return Palette.tiffany
    }
}

struct HitRow: View {
    let hit: PUAClassifier.Hit

    var body: some View {
        HStack(spacing: 10) {
            // Category badge
            Text(hit.category.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Palette.background)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.warning))

            // Matched phrase
            Text(hit.phrase)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.red)
                .lineLimit(1)

            Spacer()

            // Weight
            Text("\(Int(hit.weight))")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}
