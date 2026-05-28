import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class PUADetectorViewModel: ObservableObject {
    @Published var score: Double = 20
    @Published var lastHeard: String = ""
    @Published var riskSummary: String = "未開始偵測"
    @Published var topCategories: [PUAClassifier.Category] = []
    @Published var recentHits: [PUAClassifier.Hit] = []
    @Published var scoreHistory: [Double] = Array(repeating: 20, count: 24)
    @Published var activeLocaleDescription: String = "未啟動"
    @Published var isRunning: Bool = false
    @Published var isStarting: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var permissionMessage: String = ""
    @Published var settingsImportMessage: String = ""
    @Published var transcriptHistory: [TranscriptSegment] = []

    @AppStorage("allowBackgroundDetection") var allowBackground: Bool = false {
        didSet {
            listener.allowBackground = allowBackground
            // Only bounce the audio session if the user is actively listening.
            if userWantsListening && isRunning && oldValue != allowBackground {
                listener.stop()
                listener.start { _ in }
            }
        }
    }
    @AppStorage("privacyMode") var privacyMode: Bool = true
    @AppStorage("alertMode") private var alertModeRaw: String = AlertMode.vibration.rawValue
    @AppStorage("alertVoiceLanguage") private var alertVoiceLanguageRaw: String = AlertVoiceLanguage.english.rawValue
    @AppStorage("sensitivityLevel") private var sensitivityRaw: String = SensitivityLevel.medium.rawValue
    @AppStorage("disabledCategoryRawValues") private var disabledCategoryRawValues: String = ""
    @AppStorage("categoryPreset") private var categoryPresetRaw: String = CategoryPreset.full.rawValue
    @AppStorage("calibrationUsefulCount") private var calibrationUsefulCount: Int = 0
    @AppStorage("calibrationFalsePositiveCount") private var calibrationFalsePositiveCount: Int = 0
    private let listener = SpeechListener()
    private lazy var voice = VoiceAlert()
    private var rollingTranscript: String = ""
    private var transcriptDebounceWork: DispatchWorkItem?
    private var decayTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lifecycleSubs: Set<AnyCancellable> = []
    /// True only between an explicit user "start" and the next "stop". All
    /// lifecycle-driven (re)starts gate on this so the mic doesn't get
    /// silently re-armed after the user turned detection off.
    private var userWantsListening: Bool = false
    /// Wall clock of the last auto-retry, to back off if the listener keeps
    /// dying.
    private var lastAutoRetry: Date = .distantPast
    private var autoRetryCount: Int = 0

    init() {
        listener.onTranscript = { [weak self] text in
            Task { @MainActor in self?.handle(transcript: text) }
        }
        listener.onError = { [weak self] error in
            Task { @MainActor in self?.handleListenerError(error) }
        }
        listener.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.activeLocaleDescription = status }
        }
        listener.allowBackground = allowBackground
        refreshContextualHints()
        observeAppLifecycle()
    }

    var alertMode: AlertMode {
        get { AlertMode(rawValue: alertModeRaw) ?? .vibration }
        set { alertModeRaw = newValue.rawValue }
    }

    var alertVoiceLanguage: AlertVoiceLanguage {
        get { AlertVoiceLanguage(rawValue: alertVoiceLanguageRaw) ?? .english }
        set { alertVoiceLanguageRaw = newValue.rawValue }
    }

    var sensitivity: SensitivityLevel {
        get { SensitivityLevel(rawValue: sensitivityRaw) ?? .medium }
        set { sensitivityRaw = newValue.rawValue }
    }

    var alertThreshold: Double {
        sensitivity.alertThreshold
    }

    var riskLevel: RiskLevel {
        RiskLevel.level(for: score, threshold: alertThreshold)
    }

    var categoryPreset: CategoryPreset {
        get { CategoryPreset(rawValue: categoryPresetRaw) ?? .full }
        set {
            categoryPresetRaw = newValue.rawValue
            guard newValue != .custom else { return }
            disabledCategories = newValue.disabledCategories
        }
    }

    var disabledCategories: Set<PUAClassifier.Category> {
        get {
            Set(disabledCategoryRawValues
                .split(separator: ",")
                .compactMap { PUAClassifier.Category(rawValue: String($0)) })
        }
        set {
            disabledCategoryRawValues = newValue
                .map(\.rawValue)
                .sorted()
                .joined(separator: ",")
            refreshContextualHints()
            reEvaluateRollingTranscript()
        }
    }

    func isCategoryEnabled(_ category: PUAClassifier.Category) -> Bool {
        !disabledCategories.contains(category)
    }

    func setCategory(_ category: PUAClassifier.Category, enabled: Bool) {
        var disabled = disabledCategories
        if enabled {
            disabled.remove(category)
        } else {
            disabled.insert(category)
        }
        categoryPresetRaw = CategoryPreset.custom.rawValue
        disabledCategories = disabled
    }

    func resetCategoryFilters() {
        categoryPreset = .full
    }

    var enabledCategoryCount: Int {
        PUAClassifier.Category.allCases.count - disabledCategories.count
    }

    var currentReport: DetectionReport {
        DetectionReport(generatedAt: Date(),
                        score: score,
                        riskLevel: riskLevel,
                        categories: topCategories,
                        hits: recentHits,
                        disabledCategories: disabledCategories,
                        categoryPreset: categoryPreset,
                        threshold: alertThreshold,
                        locale: activeLocaleDescription,
                        privacyStatus: privacyStatus)
    }

    var calibrationSummary: CalibrationSummary {
        CalibrationSummary(usefulCount: calibrationUsefulCount,
                           falsePositiveCount: calibrationFalsePositiveCount)
    }

    var privacyStatus: PrivacyStatus {
        PrivacyStatus(privacyMode: privacyMode,
                      backgroundDetection: allowBackground,
                      storesTranscript: false,
                      sharesTranscript: false)
    }

    var settingsSnapshot: DetectionSettingsSnapshot {
        DetectionSettingsSnapshot(sensitivity: sensitivity,
                                  alertMode: alertMode,
                                  alertVoiceLanguage: alertVoiceLanguage,
                                  categoryPreset: categoryPreset,
                                  disabledCategories: disabledCategories.sorted { $0.rawValue < $1.rawValue },
                                  privacyMode: privacyMode,
                                  allowBackgroundDetection: allowBackground)
    }

    var exportedSettingsText: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settingsSnapshot),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    @discardableResult
    func importSettings(from text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(DetectionSettingsSnapshot.self, from: data),
              snapshot.version == 1 else {
            settingsImportMessage = "設定格式無法讀取"
            return false
        }

        sensitivity = snapshot.sensitivity
        alertMode = snapshot.alertMode
        alertVoiceLanguage = snapshot.alertVoiceLanguage
        privacyMode = snapshot.privacyMode
        allowBackground = snapshot.allowBackgroundDetection
        categoryPresetRaw = snapshot.categoryPreset.rawValue
        disabledCategories = Set(snapshot.disabledCategories)
        settingsImportMessage = "設定已匯入"
        return true
    }

    func requestPermissions() {
        listener.requestAuthorization { [weak self] granted, message in
            guard let self else { return }
            if !granted {
                self.permissionMessage = message ?? "權限被拒。"
                self.showPermissionAlert = true
            }
        }
    }

    /// Called from the splash screen / scene appearance — no longer starts
    /// listening automatically. The user opts in by tapping "開始偵測".
    func autoStartIfAuthorised() {
        // Intentionally a no-op: the mic should only be live when the user
        // explicitly asks for it. Kept for callsite compatibility.
    }

    func toggle() {
        if isRunning || userWantsListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isStarting else { return }
        userWantsListening = true
        isStarting = true
        listener.start { [weak self] result in
            guard let self else { return }
            self.isStarting = false
            // If the user already hit stop while we were spinning up, honour it.
            guard self.userWantsListening else {
                self.listener.stop()
                self.isRunning = false
                return
            }
            switch result {
            case .success:
                self.isRunning = true
                self.autoRetryCount = 0
                self.recordScore(self.score)
                self.startDecayTimer()
            case .failure(let error):
                self.userWantsListening = false
                self.isRunning = false
                self.permissionMessage = "無法啟動語音辨識：\(error.localizedDescription)"
                self.showPermissionAlert = true
            }
        }
    }

    private func handleListenerError(_ error: Error) {
        // If the user still wants detection on, transparently retry — these
        // errors are usually transient (recogniser timeout, route change,
        // brief interruption). After a small handful of rapid failures, give
        // up and tell the user.
        guard userWantsListening else {
            isRunning = false
            isStarting = false
            return
        }

        let now = Date()
        if now.timeIntervalSince(lastAutoRetry) > 10 {
            autoRetryCount = 0
        }
        autoRetryCount += 1
        lastAutoRetry = now

        if autoRetryCount <= 3 {
            isRunning = false
            isStarting = false
            // Brief delay so we don't spin.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.userWantsListening, !self.isStarting else { return }
                self.start()
            }
        } else {
            // Bailing — surface the actual error so the user can fix it.
            userWantsListening = false
            isRunning = false
            isStarting = false
            permissionMessage = "語音辨識多次中斷：\(error.localizedDescription)"
            showPermissionAlert = true
        }
    }

    func stop() {
        userWantsListening = false
        listener.stop()
        isRunning = false
        isStarting = false
        decayTimer?.invalidate()
        decayTimer = nil
        transcriptDebounceWork?.cancel()
        transcriptDebounceWork = nil
        score = 20
        lastHeard = ""
        rollingTranscript = ""
        transcriptHistory = []
        riskSummary = "偵測已停止"
        topCategories = []
        recentHits = []
        scoreHistory = Array(repeating: 20, count: 24)
        endBackgroundTask()
    }

    func emergencyStop() {
        stop()
        riskSummary = "已緊急停止並清除本次逐字稿"
    }

    func evaluateManualText(_ text: String) {
        apply(result: PUAClassifier.evaluate(text, disabledCategories: disabledCategories),
              transcript: text,
              allowAlert: false)
    }

    func recordCalibrationFeedback(_ feedback: CalibrationFeedback) {
        switch feedback {
        case .useful:
            calibrationUsefulCount += 1
        case .falsePositive:
            calibrationFalsePositiveCount += 1
        }
    }

    func resetCalibrationFeedback() {
        calibrationUsefulCount = 0
        calibrationFalsePositiveCount = 0
    }

    func restorePrivacyDefaults() {
        privacyMode = true
        allowBackground = false
        alertMode = .vibration
        alertVoiceLanguage = .english
        sensitivity = .medium
        categoryPreset = .full
    }

    private func handle(transcript: String) {
        // Keep only the most recent slice so old phrases don't permanently
        // pin the score high.
        let trimmed = String(transcript.suffix(160))
        apply(result: PUAClassifier.evaluate(trimmed, disabledCategories: disabledCategories),
              transcript: trimmed,
              allowAlert: true)
    }

    private func apply(result: PUAClassifier.Result, transcript: String, allowAlert: Bool) {
        rollingTranscript = transcript
        lastHeard = privacyMode ? "" : transcript
        riskSummary = result.summary
        topCategories = Array(result.topCategories.prefix(3))
        recentHits = Array(result.hits.sorted { $0.weight > $1.weight }.prefix(5))
        if allowAlert && result.score < score {
            // Live detection decays down gently so transient ASR revisions do
            // not make the gauge jitter. Manual/filter recalculations use the
            // exact score immediately.
        } else {
            score = result.score
        }
        recordScore(score)

        // Add to transcript history with debounce (avoid flood during live ASR)
        transcriptDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let segment = TranscriptSegment(
                text: transcript,
                hits: Array(result.hits),
                score: result.score,
                timestamp: Date()
            )
            self.transcriptHistory.append(segment)
            // Keep last 50 segments
            if self.transcriptHistory.count > 50 {
                self.transcriptHistory.removeFirst(self.transcriptHistory.count - 50)
            }
        }
        transcriptDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)

        if allowAlert && result.score >= alertThreshold {
            playAlert()
        }
    }

    private func playAlert() {
        switch alertMode {
        case .voice:
            voice.play(language: alertVoiceLanguage)
        case .vibration:
            voice.vibrate()
        case .both:
            voice.vibrate()
            voice.play(language: alertVoiceLanguage)
        case .silent:
            break
        }
    }

    private func startDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.score > 22 {
                    self.score = max(22, self.score - 1.5)
                    self.recordScore(self.score)
                }
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func recordScore(_ value: Double) {
        scoreHistory.append(value)
        if scoreHistory.count > 24 {
            scoreHistory.removeFirst(scoreHistory.count - 24)
        }
    }

    private func reEvaluateRollingTranscript() {
        guard !rollingTranscript.isEmpty else { return }
        apply(result: PUAClassifier.evaluate(rollingTranscript, disabledCategories: disabledCategories),
              transcript: rollingTranscript,
              allowAlert: false)
    }

    private func refreshContextualHints() {
        listener.contextualHints = PUAClassifier
            .patterns(disabledCategories: disabledCategories)
            .sorted { $0.count < $1.count }
    }

    private func observeAppLifecycle() {
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.handleEnterBackground() }
            .store(in: &lifecycleSubs)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.handleEnterForeground() }
            .store(in: &lifecycleSubs)
    }

    private func handleEnterBackground() {
        guard isRunning, userWantsListening else { return }
        if allowBackground {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "PUADetector.listen") { [weak self] in
                self?.endBackgroundTask()
            }
        } else {
            stop()
        }
    }

    private func handleEnterForeground() {
        endBackgroundTask()
        // Only re-arm if the user had detection on and iOS killed the session
        // while backgrounded. A manual stop must stay stopped.
        if userWantsListening && !isRunning && !isStarting && SpeechListener.hasAllPermissions {
            start()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

/// A single segment of recognised speech with its PUA analysis results.
struct TranscriptSegment: Identifiable {
    let id = UUID()
    let text: String
    let hits: [PUAClassifier.Hit]
    let score: Double
    let timestamp: Date

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}
