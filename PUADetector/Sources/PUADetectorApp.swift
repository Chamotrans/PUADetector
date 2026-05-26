import SwiftUI

@main
struct PUADetectorApp: App {
    @State private var didPassSplash: Bool = Self.shouldSkipSplash || SpeechListener.hasAllPermissions

    init() {
        if ProcessInfo.processInfo.arguments.contains("-UITestResetDefaults") {
            Self.resetPersistentSettings()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if didPassSplash {
                    ContentView()
                } else {
                    SplashView(onContinue: { didPassSplash = true })
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.35), value: didPassSplash)
        }
    }

    private static var shouldSkipSplash: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestSkipSplash")
    }

    private static func resetPersistentSettings() {
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
            "calibrationFalsePositiveCount",
            "llmRelayEndpoint",
            "llmRelayToken",
            "llmRelayServiceKey"
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
