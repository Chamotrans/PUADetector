import Foundation

struct DetectionReport {
    let generatedAt: Date
    let score: Double
    let riskLevel: RiskLevel
    let categories: [PUAClassifier.Category]
    let hits: [PUAClassifier.Hit]
    let disabledCategories: Set<PUAClassifier.Category>
    let categoryPreset: CategoryPreset
    let threshold: Double
    let locale: String
    let privacyStatus: PrivacyStatus

    var shareText: String {
        var lines: [String] = [
            "PUA Detector report",
            "Generated: \(Self.dateFormatter.string(from: generatedAt))",
            "Risk: \(riskLevel.title)",
            "Score: \(String(format: "%.0f", score)) / threshold \(String(format: "%.0f", threshold))",
            "Category preset: \(categoryPreset.title)",
            "Recognizer: \(locale)",
            "Privacy: \(privacyStatus.summary)",
            ""
        ]

        if categories.isEmpty {
            lines.append("Categories: none")
        } else {
            lines.append("Categories: \(categories.map(\.displayName).joined(separator: ", "))")
        }

        if !hits.isEmpty {
            lines.append("")
            lines.append("Top signals:")
            for hit in hits.prefix(5) {
                lines.append("- \(hit.category.displayName), weight \(String(format: "%.0f", hit.weight)), similarity \(String(format: "%.2f", hit.similarity)), severity \(hit.severity.rawValue)")
            }
        }

        if !disabledCategories.isEmpty {
            lines.append("")
            lines.append("Disabled categories: \(disabledCategories.map(\.displayName).sorted().joined(separator: ", "))")
        }

        lines.append("")
        lines.append("No live transcript is included in this report.")
        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
