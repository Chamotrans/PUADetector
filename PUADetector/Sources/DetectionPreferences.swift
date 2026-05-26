import Foundation

enum AlertMode: String, CaseIterable, Identifiable {
    case voice
    case vibration
    case both
    case silent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice: return "語音"
        case .vibration: return "震動"
        case .both: return "語音+震動"
        case .silent: return "靜默"
        }
    }
}

enum SensitivityLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var alertThreshold: Double {
        switch self {
        case .low: return 55
        case .medium: return 40
        case .high: return 32
        }
    }
}

enum AlertVoiceLanguage: String, CaseIterable, Identifiable {
    case english
    case cantonese
    case mandarin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: return "English"
        case .cantonese: return "廣東話"
        case .mandarin: return "普通話"
        }
    }

    var spokenText: String {
        switch self {
        case .english: return "P U A detected"
        case .cantonese: return "偵測到操縱語句"
        case .mandarin: return "检测到操纵话术"
        }
    }

    var voiceLanguagePrefixes: [String] {
        switch self {
        case .english: return ["en"]
        case .cantonese: return ["zh-HK", "yue"]
        case .mandarin: return ["zh-CN", "zh-TW", "zh"]
        }
    }
}

enum RiskLevel: String, CaseIterable {
    case clear
    case watch
    case warning
    case danger

    var title: String {
        switch self {
        case .clear: return "低風險"
        case .watch: return "留意"
        case .warning: return "警示"
        case .danger: return "高風險"
        }
    }

    var symbolName: String {
        switch self {
        case .clear: return "checkmark.shield.fill"
        case .watch: return "eye.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }

    static func level(for score: Double, threshold: Double) -> RiskLevel {
        if score >= threshold { return .danger }
        if score >= 65 { return .warning }
        if score >= 40 { return .watch }
        return .clear
    }
}

enum CategoryPreset: String, CaseIterable, Identifiable {
    case full
    case balanced
    case safety
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "全量"
        case .balanced: return "平衡"
        case .safety: return "安全優先"
        case .custom: return "自訂"
        }
    }

    var disabledCategories: Set<PUAClassifier.Category> {
        switch self {
        case .full, .custom:
            return []
        case .balanced:
            return [
                .appearance,
                .breadcrumb,
                .jealousy,
                .loveBombing,
                .stonewall
            ]
        case .safety:
            let enabled: Set<PUAClassifier.Category> = [
                .threat,
                .ownership,
                .isolation,
                .finance,
                .guilt,
                .conditional,
                .blameShifting,
                .gaslighting
            ]
            return Set(PUAClassifier.Category.allCases).subtracting(enabled)
        }
    }
}

enum CalibrationFeedback: String {
    case useful
    case falsePositive

    var title: String {
        switch self {
        case .useful: return "有幫助"
        case .falsePositive: return "誤報"
        }
    }
}

struct CalibrationSummary {
    let usefulCount: Int
    let falsePositiveCount: Int

    var totalCount: Int {
        usefulCount + falsePositiveCount
    }

    var usefulRateText: String {
        guard totalCount > 0 else { return "未有資料" }
        let rate = Double(usefulCount) / Double(totalCount) * 100
        return String(format: "%.0f%%", rate)
    }
}

struct PrivacyStatus: Equatable {
    let privacyMode: Bool
    let backgroundDetection: Bool
    let storesTranscript: Bool
    let sharesTranscript: Bool

    var summary: String {
        [
            privacyMode ? "隱私模式開啟" : "隱私模式關閉",
            backgroundDetection ? "背景偵測開啟" : "背景偵測關閉",
            storesTranscript ? "會保存逐字稿" : "不保存逐字稿",
            sharesTranscript ? "報告包含逐字稿" : "報告不包含逐字稿"
        ].joined(separator: " · ")
    }
}

struct DetectionSettingsSnapshot: Codable, Equatable {
    let version: Int
    let sensitivity: SensitivityLevel
    let alertMode: AlertMode
    let alertVoiceLanguage: AlertVoiceLanguage
    let categoryPreset: CategoryPreset
    let disabledCategories: [PUAClassifier.Category]
    let privacyMode: Bool
    let allowBackgroundDetection: Bool

    init(version: Int = 1,
         sensitivity: SensitivityLevel,
         alertMode: AlertMode,
         alertVoiceLanguage: AlertVoiceLanguage,
         categoryPreset: CategoryPreset,
         disabledCategories: [PUAClassifier.Category],
         privacyMode: Bool,
         allowBackgroundDetection: Bool) {
        self.version = version
        self.sensitivity = sensitivity
        self.alertMode = alertMode
        self.alertVoiceLanguage = alertVoiceLanguage
        self.categoryPreset = categoryPreset
        self.disabledCategories = disabledCategories
        self.privacyMode = privacyMode
        self.allowBackgroundDetection = allowBackgroundDetection
    }
}

extension AlertMode: Codable {}
extension SensitivityLevel: Codable {}
extension AlertVoiceLanguage: Codable {}
extension CategoryPreset: Codable {}
extension PUAClassifier.Category: Codable {}
