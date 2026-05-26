import SwiftUI

struct SettingsView: View {
    @ObservedObject var detector: PUADetectorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var manualText: String = ""
    @State private var showingSafetyResources = false
    @State private var showingDebugDetails = false
    @State private var showingSettingsShareSheet = false
    @State private var settingsImportText = ""

    init(detector: PUADetectorViewModel) {
        self.detector = detector
        _manualText = State(initialValue: Self.launchArgumentValue(after: "-UITestManualText") ?? "")
    }

    private static func launchArgumentValue(after key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("偵測") {
                    Picker("敏感度", selection: Binding(
                        get: { detector.sensitivity },
                        set: { detector.sensitivity = $0 }
                    )) {
                        ForEach(SensitivityLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }

                    Toggle("背景偵測", isOn: $detector.allowBackground)
                    Toggle("隱私模式", isOn: $detector.privacyMode)
                }

                Section("分類") {
                    Picker("預設", selection: Binding(
                        get: { detector.categoryPreset },
                        set: { detector.categoryPreset = $0 }
                    )) {
                        ForEach(CategoryPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    LabeledContent("啟用", value: "\(detector.enabledCategoryCount)/\(PUAClassifier.Category.allCases.count)")
                    ForEach(PUAClassifier.Category.allCases) { category in
                        Toggle(category.displayName, isOn: Binding(
                            get: { detector.isCategoryEnabled(category) },
                            set: { detector.setCategory(category, enabled: $0) }
                        ))
                    }
                    Button("重設分類") {
                        detector.resetCategoryFilters()
                    }
                    .disabled(detector.disabledCategories.isEmpty)
                }

                Section("提醒") {
                    Picker("警報方式", selection: Binding(
                        get: { detector.alertMode },
                        set: { detector.alertMode = $0 }
                    )) {
                        ForEach(AlertMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Picker("語音語言", selection: Binding(
                        get: { detector.alertVoiceLanguage },
                        set: { detector.alertVoiceLanguage = $0 }
                    )) {
                        ForEach(AlertVoiceLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                }

                Section("狀態") {
                    LabeledContent("語音辨識", value: detector.activeLocaleDescription)
                    LabeledContent("警報門檻", value: String(format: "%.0f", detector.alertThreshold))
                    LabeledContent("目前分數", value: String(format: "%.0f", detector.score))
                    Button {
                        showingDebugDetails = true
                    } label: {
                        Label("查看 Debug 詳情", systemImage: "waveform.path.ecg")
                    }
                    .accessibilityIdentifier("debugDetailsButton")
                }

                Section("文字測試") {
                    TextField("輸入要測試的文字", text: $manualText, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                        .frame(minHeight: 90, alignment: .top)
                        .accessibilityIdentifier("manualTextEditor")
                    Button("測試這段文字") {
                        detector.evaluateManualText(manualText)
                    }
                    .accessibilityIdentifier("manualTestButton")
                    .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Pro LLM 深度分析") {
                    Text("只會分析你手動提交的文字；提交前會先遮蔽電話、電郵和帳號。即時偵測仍維持裝置內處理。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    TextField("Relay endpoint", text: $detector.llmRelayEndpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("llmRelayEndpointField")

                    SecureField("Amazing Tutor token（如用戶登入模式）", text: $detector.llmRelayToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("llmRelayTokenField")

                    SecureField("X-Relay-Service-Key（如 server-to-server 模式）", text: $detector.llmRelayServiceKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("llmRelayServiceKeyField")

                    Button {
                        Task { await detector.runLLMDeepScan(on: manualText) }
                    } label: {
                        if detector.isRunningLLMDeepScan {
                            Label("分析中", systemImage: "sparkles")
                        } else {
                            Label("用 LLM 深度分析這段文字", systemImage: "sparkles")
                        }
                    }
                    .accessibilityIdentifier("llmDeepScanButton")
                    .disabled(detector.isRunningLLMDeepScan || manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !detector.llmDeepScanMessage.isEmpty {
                        Text(detector.llmDeepScanMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let result = detector.llmDeepScanResult {
                        LabeledContent("風險", value: result.severity.title)
                        if !result.categories.isEmpty {
                            LabeledContent("類別", value: result.categories.map(\.displayName).joined(separator: "、"))
                        }
                        DisclosureGroup("分析原因") {
                            ForEach(result.reasons, id: \.self) { reason in
                                Text(reason)
                            }
                        }
                        DisclosureGroup("建議回覆") {
                            ForEach(result.suggestedReplies, id: \.self) { reply in
                                Text(reply)
                            }
                        }
                        DisclosureGroup("提交文字預覽") {
                            Text(result.submittedText)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Text(result.disclaimer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("校準") {
                    LabeledContent("回饋總數", value: "\(detector.calibrationSummary.totalCount)")
                    LabeledContent("有用比例", value: detector.calibrationSummary.usefulRateText)
                    LabeledContent("有幫助", value: "\(detector.calibrationSummary.usefulCount)")
                    LabeledContent("誤報", value: "\(detector.calibrationSummary.falsePositiveCount)")
                    Button("重設校準統計") {
                        detector.resetCalibrationFeedback()
                    }
                    .disabled(detector.calibrationSummary.totalCount == 0)
                }

                Section("設定備份") {
                    Button {
                        showingSettingsShareSheet = true
                    } label: {
                        Label("匯出設定", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportSettingsButton")

                    TextEditor(text: $settingsImportText)
                        .frame(minHeight: 90)

                    Button {
                        if detector.importSettings(from: settingsImportText) {
                            settingsImportText = ""
                        }
                    } label: {
                        Label("匯入貼上的設定", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("importSettingsButton")
                    .disabled(settingsImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !detector.settingsImportMessage.isEmpty {
                        Text(detector.settingsImportMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section("安全") {
                    Button {
                        detector.openSystemSettings()
                    } label: {
                        Label("開啟系統權限設定", systemImage: "gearshape.fill")
                    }

                    Button {
                        detector.restorePrivacyDefaults()
                    } label: {
                        Label("恢復私隱預設", systemImage: "lock.shield.fill")
                    }
                    .accessibilityIdentifier("restorePrivacyDefaultsButton")

                    Button {
                        showingSafetyResources = true
                    } label: {
                        Label("查看安全資源", systemImage: "cross.case.fill")
                    }
                    .accessibilityIdentifier("safetyResourcesButton")

                    Button(role: .destructive) {
                        detector.emergencyStop()
                    } label: {
                        Label("立即停止並清除本次逐字稿", systemImage: "xmark.octagon.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .sheet(isPresented: $showingSafetyResources) {
                SafetyResourcesView()
            }
            .sheet(isPresented: $showingDebugDetails) {
                DebugDetailsView(detector: detector)
            }
            .sheet(isPresented: $showingSettingsShareSheet) {
                ShareSheet(items: [detector.exportedSettingsText])
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(detector: PUADetectorViewModel())
}
