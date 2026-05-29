import SwiftUI

struct ContentView: View {
    @StateObject private var detector = PUADetectorViewModel()
    @State private var showingSettings = ProcessInfo.processInfo.arguments.contains("-showSettings")
    @State private var showingSafetyResources = ProcessInfo.processInfo.arguments.contains("-showSafetyResources")
    @State private var showingShareSheet = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 4) {
                            Text("PUA DETECTOR")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .kerning(2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .foregroundColor(Palette.tiffany)
                                .shadow(color: Palette.tiffany.opacity(0.5), radius: 8)
                            Label(detector.isRunning ? "Mic live · \(detector.activeLocaleDescription)" : "Mic off",
                                  systemImage: detector.isRunning ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(detector.isRunning ? Palette.danger : .white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Palette.tiffany)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Palette.panel))
                        }
                        .accessibilityLabel("設定")
                        .accessibilityIdentifier("settingsButton")
                    }
                    .padding(.horizontal, 20)

                    GaugeView(value: detector.score,
                              minRange: GaugeView.minValue,
                              maxRange: GaugeView.maxValue,
                              minMarker: 65,
                              peakMarker: 115)
                        .frame(height: 236)
                        .padding(.horizontal, 12)

                    RadarRippleView(active: detector.score > 90)
                        .frame(height: 72)

                    ScoreTrendView(values: detector.scoreHistory)
                        .padding(.horizontal, 24)

                    VStack(spacing: 8) {
                        Label(detector.riskLevel.title, systemImage: detector.riskLevel.symbolName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(riskColor)
                            .accessibilityIdentifier("riskLevelLabel")
                            .accessibilityLabel(detector.riskLevel.title)
                        Text(statusText)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("riskSummaryText")
                            .accessibilityLabel(statusText)
                            .accessibilityValue(riskStateAccessibilityValue)
                        if !detector.topCategories.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(detector.topCategories, id: \.self) { category in
                                    Text(category.displayName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Palette.background)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Palette.warning))
                                        .accessibilityIdentifier("categoryChip_\(category.rawValue)")
                                        .accessibilityLabel(category.displayName)
                                }
                            }
                        }
                        if !detector.lastHeard.isEmpty {
                            Text(detector.lastHeard)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, 24)

                    if detector.topCategories.contains(.threat) {
                        Button {
                            showingSafetyResources = true
                        } label: {
                            Label("查看安全資源", systemImage: "cross.case.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Palette.danger.opacity(0.72)))
                        }
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("分享診斷報告", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.82))
                    }
                    .disabled(detector.recentHits.isEmpty)

                    if !detector.recentHits.isEmpty {
                        HStack(spacing: 10) {
                            Button {
                                detector.recordCalibrationFeedback(.useful)
                            } label: {
                                Label("有幫助", systemImage: "hand.thumbsup.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                            }
                            Button {
                                detector.recordCalibrationFeedback(.falsePositive)
                            } label: {
                                Label("誤報", systemImage: "hand.thumbsdown.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.tiffany)
                        .padding(.horizontal, 24)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: detector.allowBackground ? "moon.fill" : "moon")
                            .foregroundColor(detector.allowBackground ? Palette.tiffany : .white.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("背景偵測")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text(detector.allowBackground
                                 ? "App 進入背景時繼續監聽"
                                 : "App 進入背景時自動停止")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Toggle("", isOn: $detector.allowBackground)
                            .labelsHidden()
                            .tint(Palette.tiffany)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Palette.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Palette.tiffany.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Button(action: { detector.emergencyStop() }) {
                        Label("緊急停止", systemImage: "xmark.octagon.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.panelElevated)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)

                    // ─── Transcript stream ────────────────────────────
                    TranscriptStreamView(segments: detector.transcriptHistory,
                                         isRunning: detector.isRunning)
                        .padding(.horizontal, 16)

                    Button(action: { detector.toggle() }) {
                        HStack(spacing: 10) {
                            if detector.isStarting {
                                ProgressView().tint(Palette.background)
                            }
                            Text(detector.isStarting ? "啟動中…"
                                 : (detector.isRunning ? "停止偵測" : "開始偵測"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                            .foregroundColor(Palette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(detector.isRunning ? Palette.danger : Palette.tiffany)
                            .clipShape(Capsule())
                            .shadow(color: (detector.isRunning ? Palette.danger : Palette.tiffany).opacity(0.6),
                                    radius: 12)
                    }
                    .disabled(detector.isStarting)
                    .padding(.horizontal, 24)
                }
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 18)
            }
        }
        .onAppear {
            detector.autoStartIfAuthorised()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(detector: detector)
        }
        .sheet(isPresented: $showingSafetyResources) {
            SafetyResourcesView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [detector.currentReport.shareText])
        }
        .alert("無法存取麥克風 / 語音辨識",
               isPresented: $detector.showPermissionAlert) {
            Button("好") {}
        } message: {
            Text(detector.permissionMessage)
        }
    }

    private var statusText: String {
        if detector.isStarting { return "正在啟動裝置內語音辨識" }
        if !detector.isRunning { return detector.riskSummary }
        if detector.privacyMode { return detector.riskSummary }
        return detector.lastHeard.isEmpty ? "聆聽中..." : detector.riskSummary
    }

    private var riskColor: Color {
        switch detector.riskLevel {
        case .clear: return Palette.tiffany
        case .watch: return .white.opacity(0.75)
        case .warning: return Palette.warning
        case .danger: return Palette.danger
        }
    }

    private var riskStateAccessibilityValue: String {
        let categories = detector.topCategories.map(\.rawValue).joined(separator: ",")
        return "\(detector.riskLevel.title)|\(detector.riskSummary)|\(categories)"
    }
}

#Preview {
    ContentView()
}
