import SwiftUI

struct DebugDetailsView: View {
    @ObservedObject var detector: PUADetectorViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("趨勢") {
                    ScoreTrendView(values: detector.scoreHistory)
                        .padding(.vertical, 8)
                    LabeledContent("風險等級", value: detector.riskLevel.title)
                    LabeledContent("目前分數", value: String(format: "%.0f", detector.score))
                    LabeledContent("警報門檻", value: String(format: "%.0f", detector.alertThreshold))
                }

                Section("最近命中") {
                    if detector.recentHits.isEmpty {
                        Text("暫無命中")
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        ForEach(Array(detector.recentHits.enumerated()), id: \.offset) { _, hit in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(hit.category.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                    Spacer()
                                    Text(String(format: "%.0f", hit.weight))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Palette.warning)
                                }
                                Text(hit.phrase)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.78))
                                Text("similarity \(String(format: "%.2f", hit.similarity)) · \(hit.locale.rawValue) · severity \(hit.severity.rawValue)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("辨識") {
                    LabeledContent("Locale", value: detector.activeLocaleDescription)
                    LabeledContent("私隱模式", value: detector.privacyMode ? "開" : "關")
                    LabeledContent("背景偵測", value: detector.allowBackground ? "開" : "關")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Debug")
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    DebugDetailsView(detector: PUADetectorViewModel())
}
