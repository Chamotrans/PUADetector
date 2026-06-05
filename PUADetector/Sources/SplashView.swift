import SwiftUI

struct SplashView: View {
    /// Called once the user grants (or denies) permissions.
    var onContinue: () -> Void

    @State private var requesting = false
    @State private var deniedMessage: String?

    private let listener = SpeechListener()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.background,
                                    Palette.panel],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 60)

                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(Palette.tiffany)
                        .shadow(color: Palette.tiffany.opacity(0.6), radius: 12)

                    Text("PUA DETECTOR")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .kerning(3)
                        .foregroundColor(Palette.tiffany)

                    Text("實時偵測語言中的操縱與情感勒索")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 18) {
                        InfoRow(icon: "mic.fill",
                                title: "需要麥克風權限",
                                subtitle: "App 會聆聽附近的對話，把錄音即時送入語音辨識引擎。")
                        InfoRow(icon: "lock.shield.fill",
                                title: "100% 裝置內處理",
                                subtitle: "使用 Apple 的 On-Device Speech Recognition；任何語音都不會上傳到雲端。")
                        InfoRow(icon: "character.bubble.fill",
                                title: "支援廣東話與普通話",
                                subtitle: "優先使用系統支援的廣東話辨識器，必要時自動退到 zh-CN / zh-TW。")
                        InfoRow(icon: "bell.badge.fill",
                                title: "偵測到 PUA 即時提醒",
                                subtitle: "達到危險分數時，會以語音「PUA detected」提示你。")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Palette.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Palette.tiffany.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    if let deniedMessage {
                        Text(deniedMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Palette.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 12)

                    Button(action: requestAccess) {
                        HStack(spacing: 10) {
                            if requesting {
                                ProgressView().tint(Palette.background)
                            }
                            Text(requesting ? "等待授權…" : "繼續")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Palette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.tiffany)
                        .clipShape(Capsule())
                        .shadow(color: Palette.tiffany.opacity(0.6), radius: 12)
                    }
                    .disabled(requesting)
                    .padding(.horizontal, 24)

                    Text("你可以隨時在「設定」中關閉麥克風或語音辨識權限。")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private func requestAccess() {
        requesting = true
        deniedMessage = nil
        listener.requestAuthorization { granted, message in
            requesting = false
            if granted {
                onContinue()
            } else {
                deniedMessage = message ?? "權限被拒。"
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Palette.tiffany)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SplashView(onContinue: {})
}
