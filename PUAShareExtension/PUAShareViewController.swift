import SwiftUI

/// Hosting controller for the Share Extension — wraps TextAnalyzerView.
@objc(PUAShareViewController)
class PUAShareViewController: UIHostingController<PUAShareView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: PUAShareView(sharedText: ""))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Try to extract text from the extension context
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments {
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.text") {
                    provider.loadItem(forTypeIdentifier: "public.text", options: nil) { [weak self] (text, error) in
                        guard let self = self,
                              let text = text as? String,
                              error == nil else { return }
                        DispatchQueue.main.async {
                            self.rootView = PUAShareView(sharedText: text)
                        }
                    }
                    break
                }
            }
        }
    }
}

struct PUAShareView: View {
    let sharedText: String
    @State private var result: PUAClassifier.Result?

    var body: some View {
        NavigationView {
            if let result = result {
                TextAnalyzerView(inputText: sharedText,
                                 results: result,
                                 disabledCategories: [])
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            // Dismiss share extension
                            UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .first?.keyWindow?
                                .rootViewController?
                                .dismiss(animated: true)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Palette.tiffany)
                    Text("正在分析文字...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
                .onAppear {
                    analyze()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func analyze() {
        DispatchQueue.global().async {
            let r = PUAClassifier.evaluate(self.sharedText)
            DispatchQueue.main.async {
                self.result = r
            }
        }
    }
}
