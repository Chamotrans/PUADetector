import SwiftUI

struct SafetyResourcesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("即時安全") {
                    ResourceRow(title: "如有即時危險", detail: "離開現場，到安全地方後聯絡當地緊急服務。")
                    ResourceRow(title: "保存證據", detail: "在合法情況下保存訊息、時間線和目擊者資料。")
                    ResourceRow(title: "找可信任的人", detail: "聯絡朋友、家人、輔導員或支援機構，不要獨自承受。")
                }

                Section("香港常用求助") {
                    Link(destination: URL(string: "tel:999")!) {
                        ResourceRow(title: "緊急服務 999", detail: "人身安全受威脅時使用。")
                    }
                    Link(destination: URL(string: "https://www.swd.gov.hk")!) {
                        ResourceRow(title: "社會福利署", detail: "家庭及個人支援服務資訊。")
                    }
                    Link(destination: URL(string: "https://www.18281.gov.hk")!) {
                        ResourceRow(title: "18281", detail: "香港政府家庭暴力支援資訊入口。")
                    }
                }

                Section("使用提醒") {
                    Text("PUA Detector 是輔助提醒，不是判決。分數升高時，先照顧自身安全，再判斷語境。")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("安全資源")
        }
        .preferredColorScheme(.dark)
    }
}

private struct ResourceRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.68))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SafetyResourcesView()
}
