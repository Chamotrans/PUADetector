import XCTest
@testable import PUADetector

final class PUAClassifierTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        [
            "disabledCategoryRawValues",
            "alertMode",
            "alertVoiceLanguage",
            "sensitivityLevel",
            "categoryPreset",
            "privacyMode",
            "allowBackgroundDetection",
            "calibrationUsefulCount",
            "calibrationFalsePositiveCount"
        ].forEach { defaults.removeObject(forKey: $0) }
    }

    func testCleanTranscriptStaysNearFloor() {
        let result = PUAClassifier.evaluate("今日食咩好 不如放工去買餸 然後睇戲")

        XCTAssertTrue(result.hits.isEmpty)
        XCTAssertLessThan(result.score, 30)
    }

    func testGaslightingPhraseRaisesWarningWithoutDuplicateSpike() {
        let result = PUAClassifier.evaluate("你諗多咗啦 我根本冇咁講")

        XCTAssertTrue(result.hits.contains { $0.category == .gaslighting })
        XCTAssertGreaterThanOrEqual(result.score, 75)
        XCTAssertLessThan(result.score, 120)
    }

    func testSingleHighConfidencePhraseTriggersDetection() {
        let result = PUAClassifier.evaluate("你記錯")

        XCTAssertTrue(result.hits.contains { $0.similarity >= PUAClassifier.singlePhraseDetectionSimilarity })
        XCTAssertGreaterThanOrEqual(result.score, 85)
    }

    func testThreatPhraseCrossesAlertThreshold() {
        let result = PUAClassifier.evaluate("你唔聽我就後果自負")

        XCTAssertTrue(result.hits.contains { $0.category == .threat })
        XCTAssertGreaterThanOrEqual(result.score, 85)
        XCTAssertEqual(result.topCategories.first, .threat)
    }

    func testEnglishOwnershipPhraseIsDetected() {
        let result = PUAClassifier.evaluate("give me your password now")

        XCTAssertTrue(result.hits.contains { $0.category == .ownership })
        XCTAssertGreaterThanOrEqual(result.score, 80)
    }

    func testPunctuationAndSpacesAreNormalised() {
        let normalised = PUAClassifier.normalise("你 諗 多 咗 啦！")

        XCTAssertEqual(normalised, "你諗多咗啦")
    }

    func testReportedSpeechIsDampened() {
        let direct = PUAClassifier.evaluate("你太敏感啦")
        let reported = PUAClassifier.evaluate("佢話你太敏感啦 但我覺得唔應該咁講")

        XCTAssertLessThan(reported.score, direct.score)
        XCTAssertTrue(reported.hits.contains { $0.category == .gaslighting })
    }

    func testCriticalThreatSetsSafetyRisk() {
        let result = PUAClassifier.evaluate("你再嘈 我唔知會做啲咩")

        XCTAssertTrue(result.hasSafetyRisk)
        XCTAssertEqual(result.topCategories.first, .threat)
    }

    @MainActor
    func testManualEvaluationUpdatesDebugState() {
        let model = PUADetectorViewModel()

        model.evaluateManualText("你唔聽我就後果自負")

        XCTAssertGreaterThanOrEqual(model.score, model.alertThreshold)
        XCTAssertTrue(model.topCategories.contains(.threat))
        XCTAssertFalse(model.recentHits.isEmpty)
        XCTAssertEqual(model.scoreHistory.last, model.score)
    }

    @MainActor
    func testEmergencyStopClearsTransientState() {
        let model = PUADetectorViewModel()
        model.evaluateManualText("give me your password now")

        model.emergencyStop()

        XCTAssertEqual(model.score, 20)
        XCTAssertTrue(model.recentHits.isEmpty)
        XCTAssertTrue(model.topCategories.isEmpty)
        XCTAssertEqual(model.scoreHistory, Array(repeating: 20, count: 24))
    }

    @MainActor
    func testReportOmitsTranscriptButKeepsSignals() {
        let model = PUADetectorViewModel()
        let transcript = "你唔聽我就後果自負"
        model.evaluateManualText(transcript)

        let report = model.currentReport.shareText

        XCTAssertFalse(report.contains(transcript))
        XCTAssertTrue(report.contains("No live transcript"))
        XCTAssertTrue(report.contains("Privacy:"))
        XCTAssertTrue(report.contains("不保存逐字稿"))
        XCTAssertTrue(report.contains("報告不包含逐字稿"))
        XCTAssertTrue(report.contains("威脅"))
        XCTAssertEqual(model.riskLevel, .danger)
    }

    func testRiskLevelThresholds() {
        XCTAssertEqual(RiskLevel.level(for: 20, threshold: 40), .clear)
        XCTAssertEqual(RiskLevel.level(for: 39, threshold: 40), .clear)
        XCTAssertEqual(RiskLevel.level(for: 40, threshold: 40), .danger)
        XCTAssertEqual(RiskLevel.level(for: 70, threshold: 85), .warning)
    }

    func testDisabledCategoryIsIgnoredByClassifier() {
        let result = PUAClassifier.evaluate("你唔聽我就後果自負", disabledCategories: [.threat])

        XCTAssertFalse(result.hits.contains { $0.category == .threat })
        XCTAssertLessThan(result.score, 40)
    }

    func testDisabledCategoryIsRemovedFromContextualPatterns() {
        let patterns = PUAClassifier.patterns(disabledCategories: [.threat])

        XCTAssertFalse(patterns.contains("後果自負"))
        XCTAssertTrue(patterns.contains("你太敏感"))
    }

    @MainActor
    func testViewModelDisabledCategoryAffectsManualEvaluationAndReport() {
        let model = PUADetectorViewModel()
        model.setCategory(.threat, enabled: false)

        model.evaluateManualText("你唔聽我就後果自負")

        XCTAssertFalse(model.topCategories.contains(.threat))
        XCTAssertLessThan(model.score, model.alertThreshold)
        XCTAssertTrue(model.currentReport.shareText.contains("Disabled categories"))
        XCTAssertTrue(model.currentReport.shareText.contains(PUAClassifier.Category.threat.displayName))
    }

    @MainActor
    func testChangingCategoryReevaluatesCurrentManualTranscript() {
        let model = PUADetectorViewModel()
        model.evaluateManualText("你唔聽我就後果自負")
        XCTAssertEqual(model.riskLevel, .danger)

        model.setCategory(.threat, enabled: false)

        XCTAssertFalse(model.topCategories.contains(.threat))
        XCTAssertLessThan(model.score, model.alertThreshold)
        XCTAssertTrue(model.recentHits.isEmpty)
    }

    @MainActor
    func testResetCategoryFiltersRestoresAllCategories() {
        let model = PUADetectorViewModel()
        model.setCategory(.threat, enabled: false)
        model.setCategory(.appearance, enabled: false)

        model.resetCategoryFilters()

        XCTAssertTrue(model.disabledCategories.isEmpty)
        XCTAssertEqual(model.categoryPreset, .full)
        XCTAssertEqual(model.enabledCategoryCount, PUAClassifier.Category.allCases.count)
    }

    @MainActor
    func testCategoryPresetAppliesDisabledCategories() {
        let model = PUADetectorViewModel()

        model.categoryPreset = .safety

        XCTAssertEqual(model.categoryPreset, .safety)
        XCTAssertFalse(model.disabledCategories.contains(.threat))
        XCTAssertFalse(model.disabledCategories.contains(.ownership))
        XCTAssertTrue(model.disabledCategories.contains(.appearance))
        XCTAssertTrue(model.disabledCategories.contains(.loveBombing))
    }

    @MainActor
    func testManualCategoryChangeMarksPresetCustom() {
        let model = PUADetectorViewModel()
        model.categoryPreset = .balanced

        model.setCategory(.appearance, enabled: true)

        XCTAssertEqual(model.categoryPreset, .custom)
        XCTAssertFalse(model.disabledCategories.contains(.appearance))
    }

    @MainActor
    func testReportIncludesCategoryPreset() {
        let model = PUADetectorViewModel()
        model.categoryPreset = .balanced
        model.evaluateManualText("你太敏感啦")

        XCTAssertTrue(model.currentReport.shareText.contains("Category preset: \(CategoryPreset.balanced.title)"))
    }

    @MainActor
    func testCalibrationFeedbackStoresOnlyAggregateCounts() {
        let model = PUADetectorViewModel()
        let transcript = "你唔聽我就後果自負"

        model.evaluateManualText(transcript)
        model.recordCalibrationFeedback(.useful)
        model.recordCalibrationFeedback(.falsePositive)
        model.recordCalibrationFeedback(.falsePositive)

        XCTAssertEqual(model.calibrationSummary.usefulCount, 1)
        XCTAssertEqual(model.calibrationSummary.falsePositiveCount, 2)
        XCTAssertEqual(model.calibrationSummary.totalCount, 3)
        XCTAssertEqual(model.calibrationSummary.usefulRateText, "33%")
        XCTAssertFalse(model.currentReport.shareText.contains(transcript))
    }

    @MainActor
    func testResetCalibrationFeedbackClearsCounts() {
        let model = PUADetectorViewModel()
        model.recordCalibrationFeedback(.useful)
        model.recordCalibrationFeedback(.falsePositive)

        model.resetCalibrationFeedback()

        XCTAssertEqual(model.calibrationSummary.totalCount, 0)
        XCTAssertEqual(model.calibrationSummary.usefulRateText, "未有資料")
    }

    @MainActor
    func testSettingsExportRoundTripsWithoutTranscript() throws {
        let source = PUADetectorViewModel()
        let transcript = "你唔聽我就後果自負"
        source.sensitivity = .high
        source.alertMode = .both
        source.alertVoiceLanguage = .cantonese
        source.privacyMode = false
        source.allowBackground = true
        source.setCategory(.appearance, enabled: false)
        source.evaluateManualText(transcript)

        let exported = source.exportedSettingsText
        let snapshot = try JSONDecoder().decode(DetectionSettingsSnapshot.self,
                                                from: XCTUnwrap(exported.data(using: .utf8)))

        XCTAssertEqual(snapshot.version, 1)
        XCTAssertEqual(snapshot.sensitivity, .high)
        XCTAssertEqual(snapshot.alertMode, .both)
        XCTAssertEqual(snapshot.alertVoiceLanguage, .cantonese)
        XCTAssertTrue(snapshot.disabledCategories.contains(.appearance))
        XCTAssertFalse(exported.contains(transcript))

        let imported = PUADetectorViewModel()
        XCTAssertTrue(imported.importSettings(from: exported))
        XCTAssertEqual(imported.sensitivity, .high)
        XCTAssertEqual(imported.alertMode, .both)
        XCTAssertEqual(imported.alertVoiceLanguage, .cantonese)
        XCTAssertFalse(imported.privacyMode)
        XCTAssertTrue(imported.allowBackground)
        XCTAssertTrue(imported.disabledCategories.contains(.appearance))
        XCTAssertEqual(imported.categoryPreset, .custom)
    }

    @MainActor
    func testInvalidSettingsImportDoesNotOverwriteCurrentSettings() {
        let model = PUADetectorViewModel()
        model.sensitivity = .low
        model.alertMode = .silent

        XCTAssertFalse(model.importSettings(from: "{ nope"))

        XCTAssertEqual(model.sensitivity, .low)
        XCTAssertEqual(model.alertMode, .silent)
        XCTAssertEqual(model.settingsImportMessage, "設定格式無法讀取")
    }

    @MainActor
    func testRestorePrivacyDefaultsReturnsToConservativeSettings() {
        let model = PUADetectorViewModel()
        model.privacyMode = false
        model.allowBackground = true
        model.alertMode = .voice
        model.alertVoiceLanguage = .mandarin
        model.sensitivity = .high
        model.setCategory(.threat, enabled: false)

        model.restorePrivacyDefaults()

        XCTAssertTrue(model.privacyMode)
        XCTAssertFalse(model.allowBackground)
        XCTAssertEqual(model.alertMode, .vibration)
        XCTAssertEqual(model.alertVoiceLanguage, .english)
        XCTAssertEqual(model.sensitivity, .medium)
        XCTAssertTrue(model.disabledCategories.isEmpty)
        XCTAssertEqual(model.categoryPreset, .full)
    }

    @MainActor
    func testPrivacyStatusNeverClaimsTranscriptStorageOrSharing() {
        let model = PUADetectorViewModel()
        model.privacyMode = false
        model.allowBackground = true

        XCTAssertFalse(model.privacyStatus.storesTranscript)
        XCTAssertFalse(model.privacyStatus.sharesTranscript)
        XCTAssertTrue(model.privacyStatus.summary.contains("背景偵測開啟"))
        XCTAssertTrue(model.privacyStatus.summary.contains("不保存逐字稿"))
    }

    func testSettingsSchemaDocumentsAllExportedEnumCases() throws {
        let schemaURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/settings-schema.json")
        let data = try Data(contentsOf: schemaURL)
        let schema = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let properties = try XCTUnwrap(schema?["properties"] as? [String: Any])

        XCTAssertSchemaEnum(properties, "sensitivity", SensitivityLevel.allCases.map(\.rawValue))
        XCTAssertSchemaEnum(properties, "alertMode", AlertMode.allCases.map(\.rawValue))
        XCTAssertSchemaEnum(properties, "alertVoiceLanguage", AlertVoiceLanguage.allCases.map(\.rawValue))
        XCTAssertSchemaEnum(properties, "categoryPreset", CategoryPreset.allCases.map(\.rawValue))

        let disabledCategories = try XCTUnwrap(properties["disabledCategories"] as? [String: Any])
        let items = try XCTUnwrap(disabledCategories["items"] as? [String: Any])
        let categoryEnum = try XCTUnwrap(items["enum"] as? [String])
        XCTAssertEqual(Set(categoryEnum), Set(PUAClassifier.Category.allCases.map(\.rawValue)))
    }

    private func XCTAssertSchemaEnum(_ properties: [String: Any],
                                     _ key: String,
                                     _ expected: [String],
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        guard let property = properties[key] as? [String: Any],
              let values = property["enum"] as? [String] else {
            XCTFail("Missing enum for \(key)", file: file, line: line)
            return
        }
        XCTAssertEqual(Set(values), Set(expected), file: file, line: line)
    }
}
