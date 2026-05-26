import Foundation

struct LLMDeepScanResult: Equatable {
    let submittedText: String
    let severity: RiskLevel
    let categories: [PUAClassifier.Category]
    let reasons: [String]
    let suggestedReplies: [String]
    let disclaimer: String
}

protocol LLMDeepScanning {
    func analyze(_ text: String, localResult: PUAClassifier.Result) async throws -> LLMDeepScanResult
}

enum LLMDeepScanError: LocalizedError, Equatable {
    case emptyText
    case proRequired
    case invalidEndpoint
    case badStatus(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "請先輸入要分析的對話。"
        case .proRequired:
            return "LLM 深度分析屬於 Pro 功能。"
        case .invalidEndpoint:
            return "LLM relay endpoint 格式無法讀取。"
        case .badStatus(let code):
            return "LLM relay 回傳錯誤狀態：\(code)"
        case .invalidResponse:
            return "LLM relay 回應格式無法讀取。"
        }
    }
}

struct LLMDeepScanRedactor {
    static func redact(_ text: String) -> String {
        var redacted = text
        let patterns: [(String, String)] = [
            (#"[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}"#, "[email]"),
            (#"\+?\d[\d\s\-()]{6,}\d"#, "[phone]"),
            (#"\b[A-Za-z0-9._%+-]{3,}@[A-Za-z0-9.-]+\b"#, "[account]")
        ]

        for (pattern, replacement) in patterns {
            redacted = redacted.replacingOccurrences(of: pattern,
                                                     with: replacement,
                                                     options: .regularExpression)
        }
        return redacted
    }
}

struct DeepSeekRelayLLMDeepScanService: LLMDeepScanning {
    let endpoint: URL
    let bearerToken: String
    let serviceKey: String
    var session: URLSession = .shared

    func analyze(_ text: String, localResult: PUAClassifier.Result) async throws -> LLMDeepScanResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMDeepScanError.emptyText }

        let redacted = LLMDeepScanRedactor.redact(trimmed)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !bearerToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if !serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(serviceKey, forHTTPHeaderField: "X-Relay-Service-Key")
        }
        request.httpBody = try JSONEncoder().encode(Self.requestBody(redactedText: redacted,
                                                                      localResult: localResult))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMDeepScanError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw LLMDeepScanError.badStatus(http.statusCode)
        }

        return try Self.parseResult(data, redactedText: redacted, fallback: localResult)
    }

    static func parseResult(_ data: Data,
                            redactedText: String,
                            fallback: PUAClassifier.Result) throws -> LLMDeepScanResult {
        let decoder = JSONDecoder()
        let payload: LLMDeepScanPayload
        if let direct = try? decoder.decode(LLMDeepScanPayload.self, from: data) {
            payload = direct
        } else if let wrapped = try? decoder.decode(DeepSeekRelayResponse.self, from: data) {
            payload = wrapped.analysis
        } else if let text = String(data: data, encoding: .utf8),
                  let parsed = try? parseResultText(text) {
            payload = parsed
        } else {
            throw LLMDeepScanError.invalidResponse
        }

        let categories = payload.categories
            .compactMap(PUAClassifier.Category.init(rawValue:))
        let severity = RiskLevel(rawValue: payload.severity)
            ?? RiskLevel.level(for: fallback.score, threshold: SensitivityLevel.medium.alertThreshold)

        return LLMDeepScanResult(
            submittedText: redactedText,
            severity: severity,
            categories: categories.isEmpty ? Array(fallback.topCategories.prefix(4)) : categories,
            reasons: payload.reasons.isEmpty ? ["LLM 未提供原因。"] : payload.reasons,
            suggestedReplies: payload.suggestedReplies.isEmpty ? ["我需要時間想清楚，暫時不即時回應。"] : payload.suggestedReplies,
            disclaimer: "LLM 深度分析只作語言模式參考，不是診斷、法律意見或事實裁決。"
        )
    }

    static func parseResultText(_ content: String) throws -> LLMDeepScanPayload {
        let cleaned = stripCodeFence(content)
        guard let data = cleaned.data(using: .utf8),
              let payload = try? JSONDecoder().decode(LLMDeepScanPayload.self, from: data) else {
            throw LLMDeepScanError.invalidResponse
        }
        return payload
    }

    private static func requestBody(redactedText: String,
                                    localResult: PUAClassifier.Result) -> ChatCompletionRequest {
        let localSignals = localResult.hits.prefix(8)
            .map {
                LocalSignal(category: $0.category.rawValue,
                            phrase: $0.phrase,
                            similarity: $0.similarity,
                            weight: $0.weight)
            }

        return ChatCompletionRequest(
            task: "puaDeepScan",
            locale: "zh-HK",
            conversation: redactedText,
            localClassifier: LocalClassifierSummary(score: localResult.score,
                                                    categories: Array(localResult.topCategories.prefix(4)).map(\.rawValue),
                                                    signals: localSignals),
            responseFormat: "json",
            schemaVersion: 1
        )
    }

    private static func stripCodeFence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        return trimmed
            .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MockLLMDeepScanService: LLMDeepScanning {
    func analyze(_ text: String, localResult: PUAClassifier.Result) async throws -> LLMDeepScanResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LLMDeepScanError.emptyText }

        let redacted = LLMDeepScanRedactor.redact(trimmed)
        let categories = Array(localResult.topCategories.prefix(4))
        let severity = RiskLevel.level(for: localResult.score, threshold: SensitivityLevel.medium.alertThreshold)
        let reasons = categories.isEmpty
            ? ["未見明顯操縱語句，但仍建議留意對話是否令你感到恐懼、內疚或失去自主。"]
            : categories.map { "可能涉及\($0.displayName)語言模式。" }

        let replies: [String]
        if categories.contains(.threat) {
            replies = [
                "我而家需要先確保自己安全，這段對話稍後再處理。",
                "請不要用傷害自己或傷害他人的方式要求我回應。"
            ]
        } else if categories.contains(.ownership) || categories.contains(.isolation) {
            replies = [
                "我的聯絡和決定需要由我自己管理。",
                "我會按自己的節奏回應，不接受被控制或隔離。"
            ]
        } else {
            replies = [
                "我需要時間想清楚，暫時不即時回應。",
                "請用清楚和尊重的方式表達，不要把責任推到我身上。"
            ]
        }

        return LLMDeepScanResult(
            submittedText: redacted,
            severity: severity,
            categories: categories,
            reasons: reasons,
            suggestedReplies: replies,
            disclaimer: "LLM 深度分析只作語言模式參考，不是診斷、法律意見或事實裁決。"
        )
    }
}

private struct ChatCompletionRequest: Encodable {
    let task: String
    let locale: String
    let conversation: String
    let localClassifier: LocalClassifierSummary
    let responseFormat: String
    let schemaVersion: Int
}

private struct LocalClassifierSummary: Encodable {
    let score: Double
    let categories: [String]
    let signals: [LocalSignal]
}

private struct LocalSignal: Encodable {
    let category: String
    let phrase: String
    let similarity: Double
    let weight: Double
}

private struct DeepSeekRelayResponse: Decodable {
    let analysis: LLMDeepScanPayload
    let provider: String?
    let model: String?
    let quota: [String: Int]?
}

struct LLMDeepScanPayload: Decodable {
    let severity: String
    let categories: [String]
    let reasons: [String]
    let suggestedReplies: [String]

    enum CodingKeys: String, CodingKey {
        case severity
        case categories
        case reasons
        case suggestedReplies
    }
}
