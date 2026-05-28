import Foundation

/// On-device classifier that maps a recent transcript into a 20–130 gauge
/// score. Recognises Cantonese, Mandarin and English manipulation tropes,
/// and uses fuzzy substring matching so ASR-mangled variants still hit.
///
///   20  → clean
///   65  → MIN (some neutral/borderline phrasing)
///  115  → PEAK (clearly manipulative)
    struct PUAClassifier {
    static let singlePhraseDetectionSimilarity = 0.80
    static let singlePhraseDetectionScore = 86.0

    enum Category: String, CaseIterable, Identifiable {
        case gaslighting      // 否認現實
        case negging          // 貶低自尊
        case guilt            // 情感勒索
        case ownership        // 控制
        case isolation        // 孤立
        case conditional      // 有條件的愛
        case threat           // 恐嚇
        case blameShifting    // DARVO
        case futureFaking     // 畫餅
        case loveBombing      // 過度討好
        case breadcrumb       // 吊胃口
        case finance          // 金錢控制
        case appearance       // 外貌打壓
        case jealousy         // 嫉妒陷阱
        case dismissive       // 否定感受
        case stonewall        // 冷暴力

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .gaslighting: return "否認現實"
            case .negging: return "貶低自尊"
            case .guilt: return "情感勒索"
            case .ownership: return "控制"
            case .isolation: return "孤立"
            case .conditional: return "有條件的愛"
            case .threat: return "威脅"
            case .blameShifting: return "轉移責任"
            case .futureFaking: return "畫餅"
            case .loveBombing: return "過度示好"
            case .breadcrumb: return "吊胃口"
            case .finance: return "金錢控制"
            case .appearance: return "外貌打壓"
            case .jealousy: return "嫉妒陷阱"
            case .dismissive: return "否定感受"
            case .stonewall: return "冷處理"
            }
        }
    }

    enum PhraseLocale: String {
        case cantonese
        case mandarin
        case english
        case mixed
    }

    enum Severity: Int {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }

    struct Phrase {
        let pattern: String
        let weight: Double
        let category: Category
        let locale: PhraseLocale
        let severity: Severity

        init(pattern: String,
             weight: Double,
             category: Category,
             locale: PhraseLocale = .mixed,
             severity: Severity = .medium) {
            self.pattern = pattern
            self.weight = weight
            self.category = category
            self.locale = locale
            self.severity = severity
        }
    }

    struct Hit {
        let phrase: String
        let weight: Double
        let category: Category
        let locale: PhraseLocale
        let severity: Severity
        let similarity: Double   // 1.0 = exact, lower = fuzzy
    }

    struct Result {
        let score: Double
        let hits: [Hit]
        var topHit: Hit? { hits.max { $0.weight < $1.weight } }
        var hasSafetyRisk: Bool { hits.contains { $0.category == .threat || $0.severity == .critical } }

        var topCategories: [Category] {
            let totals = Dictionary(grouping: hits, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.weight } }
            return totals.sorted { $0.value > $1.value }.map(\.key)
        }

        var summary: String {
            guard let top = topCategories.first else { return "未見明顯操縱語句" }
            if top == .threat {
                return "偵測到威脅或自傷脅迫傾向"
            }
            return "偵測到\(top.displayName)傾向"
        }
    }

    // MARK: - Phrase bank

    /// Weighted phrase list. Heavy on subtle phrasing because that's where
    /// PUA dynamics hide. Mix of zh-HK / zh-CN / English.
    static let phrases: [Phrase] = [

        // ─── Gaslighting / reality denial ────────────────────────────────
        .init(pattern: "你諗多咗",         weight: 22, category: .gaslighting),
        .init(pattern: "你諗多咗啦",       weight: 22, category: .gaslighting),
        .init(pattern: "你想多了",         weight: 22, category: .gaslighting),
        .init(pattern: "你太敏感",         weight: 20, category: .gaslighting),
        .init(pattern: "你太敏感啦",       weight: 20, category: .gaslighting),
        .init(pattern: "你太敏感了",       weight: 20, category: .gaslighting),
        .init(pattern: "係你諗多",         weight: 20, category: .gaslighting),
        .init(pattern: "是你想多",         weight: 20, category: .gaslighting),
        .init(pattern: "邊個同你講",       weight: 18, category: .gaslighting),
        .init(pattern: "谁跟你说的",       weight: 18, category: .gaslighting),
        .init(pattern: "我冇講過",         weight: 22, category: .gaslighting),
        .init(pattern: "我没说过",         weight: 22, category: .gaslighting),
        .init(pattern: "我幾時講過",       weight: 22, category: .gaslighting),
        .init(pattern: "我什么时候说过",   weight: 22, category: .gaslighting),
        .init(pattern: "我冇咁講過",       weight: 22, category: .gaslighting),
        .init(pattern: "我没这样说过",     weight: 22, category: .gaslighting),
        .init(pattern: "你聽錯",           weight: 18, category: .gaslighting),
        .init(pattern: "你听错了",         weight: 18, category: .gaslighting),
        .init(pattern: "你記錯",           weight: 18, category: .gaslighting),
        .init(pattern: "你记错",           weight: 18, category: .gaslighting),
        .init(pattern: "你記性差",         weight: 16, category: .gaslighting),
        .init(pattern: "你记性不好",       weight: 16, category: .gaslighting),
        .init(pattern: "你記錯咗",         weight: 18, category: .gaslighting),
        .init(pattern: "是你記錯了",       weight: 18, category: .gaslighting),
        .init(pattern: "邊有呢件事",       weight: 20, category: .gaslighting),
        .init(pattern: "哪有这回事",       weight: 20, category: .gaslighting),
        .init(pattern: "冇呢件事",         weight: 18, category: .gaslighting),
        .init(pattern: "没这回事",         weight: 18, category: .gaslighting),
        .init(pattern: "你講到好誇張",     weight: 18, category: .gaslighting),
        .init(pattern: "你说的太夸张了",   weight: 18, category: .gaslighting),
        .init(pattern: "冇咁嚴重",         weight: 16, category: .gaslighting),
        .init(pattern: "沒那么严重",       weight: 16, category: .gaslighting),
        .init(pattern: "你係咪有病",       weight: 26, category: .gaslighting),
        .init(pattern: "你是不是有病",     weight: 26, category: .gaslighting),
        .init(pattern: "你癲咗",           weight: 24, category: .gaslighting),
        .init(pattern: "你疯了",           weight: 24, category: .gaslighting),
        .init(pattern: "你又嚟",           weight: 14, category: .gaslighting),
        .init(pattern: "你又来了",         weight: 14, category: .gaslighting),
        .init(pattern: "又嚟",             weight: 12, category: .gaslighting),
        .init(pattern: "邊個信你",         weight: 18, category: .gaslighting),
        .init(pattern: "谁会信你",         weight: 18, category: .gaslighting),
        .init(pattern: "你咁講冇人信",     weight: 18, category: .gaslighting),
        .init(pattern: "你这样说没人信",   weight: 18, category: .gaslighting),
        .init(pattern: "根本冇人咁諗",     weight: 18, category: .gaslighting),
        .init(pattern: "根本没人这么想",   weight: 18, category: .gaslighting),
        .init(pattern: "你係咪玩嘢",       weight: 16, category: .gaslighting, locale: .cantonese),
        .init(pattern: "你唔好作嘢",       weight: 18, category: .gaslighting, locale: .cantonese),
        .init(pattern: "你又作嘢",         weight: 18, category: .gaslighting, locale: .cantonese),
        .init(pattern: "你咁都嬲",         weight: 18, category: .gaslighting, locale: .cantonese),
        .init(pattern: "你咁都唔開心",     weight: 18, category: .gaslighting, locale: .cantonese),
        .init(pattern: "你这都生气",       weight: 18, category: .gaslighting, locale: .mandarin),
        .init(pattern: "這有咩好嬲",       weight: 18, category: .gaslighting, locale: .cantonese),
        .init(pattern: "这有什么好气的",   weight: 18, category: .gaslighting, locale: .mandarin),
        .init(pattern: "冇嘢",             weight: 8,  category: .gaslighting),
        .init(pattern: "没事",             weight: 8,  category: .gaslighting),
        .init(pattern: "冇事發生",         weight: 14, category: .gaslighting),
        .init(pattern: "什么事都沒有",     weight: 14, category: .gaslighting),

        // ─── Dismissive / minimising feelings ────────────────────────────
        .init(pattern: "你冇嘢呀嘛",       weight: 14, category: .dismissive),
        .init(pattern: "你没事啦",         weight: 14, category: .dismissive),
        .init(pattern: "你冇事",           weight: 12, category: .dismissive),
        .init(pattern: "你没事吧",         weight: 12, category: .dismissive),
        .init(pattern: "唔好咁玻璃心",     weight: 22, category: .dismissive),
        .init(pattern: "不要这么玻璃心",   weight: 22, category: .dismissive),
        .init(pattern: "玻璃心",           weight: 12, category: .dismissive),
        .init(pattern: "至於咩",           weight: 16, category: .dismissive),
        .init(pattern: "至于吗",           weight: 16, category: .dismissive),
        .init(pattern: "至於咁",           weight: 14, category: .dismissive),
        .init(pattern: "至于这样吗",       weight: 14, category: .dismissive),
        .init(pattern: "小事啫",           weight: 12, category: .dismissive),
        .init(pattern: "小事而已",         weight: 12, category: .dismissive),
        .init(pattern: "你大驚小怪",       weight: 18, category: .dismissive),
        .init(pattern: "你大惊小怪",       weight: 18, category: .dismissive),
        .init(pattern: "唔使咁認真啩",     weight: 14, category: .dismissive),
        .init(pattern: "不用这么认真",     weight: 14, category: .dismissive),
        .init(pattern: "開玩笑啫",         weight: 12, category: .dismissive),
        .init(pattern: "开玩笑而已",       weight: 12, category: .dismissive),
        .init(pattern: "玩玩啫",           weight: 12, category: .dismissive, locale: .cantonese),
        .init(pattern: "玩玩而已",         weight: 12, category: .dismissive, locale: .mandarin),
        .init(pattern: "我講笑咋",         weight: 10, category: .dismissive, locale: .cantonese),
        .init(pattern: "我说笑的",         weight: 10, category: .dismissive, locale: .mandarin),
        .init(pattern: "你冇幽默感",       weight: 16, category: .dismissive),
        .init(pattern: "你没幽默感",       weight: 16, category: .dismissive),
        .init(pattern: "你唔好笑咁大聲",   weight: 14, category: .dismissive, locale: .cantonese),
        .init(pattern: "你別笑那麼大聲",   weight: 14, category: .dismissive, locale: .mandarin),
        .init(pattern: "算啦你唔明",       weight: 14, category: .dismissive, locale: .cantonese),
        .init(pattern: "算了你不懂",       weight: 14, category: .dismissive, locale: .mandarin),
        .init(pattern: "同你講唔明",       weight: 14, category: .dismissive, locale: .cantonese),
        .init(pattern: "跟你說不明白",     weight: 14, category: .dismissive, locale: .mandarin),
        .init(pattern: "你理得我",         weight: 12, category: .dismissive, locale: .cantonese),
        .init(pattern: "你管我",           weight: 12, category: .dismissive, locale: .mandarin),
        .init(pattern: "唔使你理",         weight: 14, category: .dismissive, locale: .cantonese),
        .init(pattern: "不用你管",         weight: 14, category: .dismissive, locale: .mandarin),

        // ─── Negging / belittling ───────────────────────────────────────
        .init(pattern: "冇人會鍾意你",     weight: 30, category: .negging),
        .init(pattern: "没人会喜欢你",     weight: 30, category: .negging),
        .init(pattern: "邊個會要你",       weight: 28, category: .negging),
        .init(pattern: "谁会要你",         weight: 28, category: .negging),
        .init(pattern: "你呢啲冇人要",     weight: 28, category: .negging),
        .init(pattern: "你这种没人要",     weight: 28, category: .negging),
        .init(pattern: "好彩有我",         weight: 22, category: .negging),
        .init(pattern: "幸好有我",         weight: 22, category: .negging),
        .init(pattern: "我先肯同你",       weight: 24, category: .negging),
        .init(pattern: "我才愿意跟你",     weight: 24, category: .negging),
        .init(pattern: "我得閒先理你",     weight: 22, category: .negging, locale: .cantonese),
        .init(pattern: "我有空才理你",     weight: 22, category: .negging, locale: .mandarin),
        .init(pattern: "我夠包容你",       weight: 22, category: .negging),
        .init(pattern: "我够包容你",       weight: 22, category: .negging),
        .init(pattern: "其他人受唔到你",   weight: 22, category: .negging),
        .init(pattern: "别人受不了你",     weight: 22, category: .negging),
        .init(pattern: "你冇我唔得",       weight: 26, category: .negging),
        .init(pattern: "你离不开我",       weight: 26, category: .negging),
        .init(pattern: "你做乜都唔掂",     weight: 22, category: .negging),
        .init(pattern: "你做什么都不行",   weight: 22, category: .negging),
        .init(pattern: "乜都做唔好",       weight: 20, category: .negging),
        .init(pattern: "什么都做不好",     weight: 20, category: .negging),
        .init(pattern: "你蠢",             weight: 14, category: .negging),
        .init(pattern: "你笨",             weight: 14, category: .negging),
        .init(pattern: "你低能",           weight: 18, category: .negging),
        .init(pattern: "你智商",           weight: 14, category: .negging),
        .init(pattern: "你唔識嘢",         weight: 16, category: .negging, locale: .cantonese),
        .init(pattern: "你不懂事",         weight: 16, category: .negging, locale: .mandarin),
        .init(pattern: "你冇用",           weight: 22, category: .negging),
        .init(pattern: "你没用",           weight: 22, category: .negging),
        .init(pattern: "你咁廢",           weight: 22, category: .negging, locale: .cantonese),
        .init(pattern: "你这么废",         weight: 22, category: .negging, locale: .mandarin),
        .init(pattern: "得你先咁麻煩",     weight: 20, category: .negging, locale: .cantonese),
        .init(pattern: "只有你这么麻烦",   weight: 20, category: .negging, locale: .mandarin),
        .init(pattern: "最煩係你",         weight: 18, category: .negging, locale: .cantonese),
        .init(pattern: "最烦就是你",       weight: 18, category: .negging, locale: .mandarin),
        .init(pattern: "你唔知幾多人追我", weight: 18, category: .negging, locale: .cantonese),
        .init(pattern: "你不知道多少人追我", weight: 18, category: .negging, locale: .mandarin),
        .init(pattern: "你唔識諗",         weight: 16, category: .negging, locale: .cantonese),
        .init(pattern: "你不会想",         weight: 16, category: .negging, locale: .mandarin),
        .init(pattern: "你幼稚",           weight: 14, category: .negging),
        .init(pattern: "你太幼稚",         weight: 14, category: .negging),
        .init(pattern: "你唔成熟",         weight: 14, category: .negging),
        .init(pattern: "你不成熟",         weight: 14, category: .negging),

        // ─── Appearance shaming ─────────────────────────────────────────
        .init(pattern: "你又肥咗",         weight: 14, category: .appearance),
        .init(pattern: "你又胖了",         weight: 14, category: .appearance),
        .init(pattern: "你好肥",           weight: 16, category: .appearance),
        .init(pattern: "你好胖",           weight: 16, category: .appearance),
        .init(pattern: "你肥咗",           weight: 14, category: .appearance),
        .init(pattern: "你胖了",           weight: 14, category: .appearance),
        .init(pattern: "你肥到",           weight: 14, category: .appearance),
        .init(pattern: "你胖得",           weight: 14, category: .appearance),
        .init(pattern: "肥成咁",           weight: 16, category: .appearance),
        .init(pattern: "胖成这样",         weight: 16, category: .appearance),
        .init(pattern: "咁肥",             weight: 12, category: .appearance),
        .init(pattern: "这么胖",           weight: 12, category: .appearance),
        .init(pattern: "肥死你",           weight: 14, category: .appearance),
        .init(pattern: "胖死你",           weight: 14, category: .appearance),
        .init(pattern: "你唔化妝就",       weight: 14, category: .appearance),
        .init(pattern: "你不化妝就",       weight: 14, category: .appearance),
        .init(pattern: "你唔化好樣衰",     weight: 18, category: .appearance, locale: .cantonese),
        .init(pattern: "你不化妆好丑",     weight: 18, category: .appearance, locale: .mandarin),
        .init(pattern: "你著成咁",         weight: 16, category: .appearance),
        .init(pattern: "你穿成这样",       weight: 16, category: .appearance),
        .init(pattern: "你樣衰",           weight: 16, category: .appearance),
        .init(pattern: "你样子不行",       weight: 16, category: .appearance),
        .init(pattern: "你好樣衰",         weight: 16, category: .appearance),
        .init(pattern: "你好丑",           weight: 16, category: .appearance),
        .init(pattern: "你咁樣衰",         weight: 16, category: .appearance),
        .init(pattern: "你长得好丑",       weight: 16, category: .appearance),
        .init(pattern: "你唔靚",           weight: 14, category: .appearance),
        .init(pattern: "你不漂亮",         weight: 14, category: .appearance),
        .init(pattern: "你面嗊大",         weight: 14, category: .appearance),
        .init(pattern: "你脸多大",         weight: 14, category: .appearance),
        .init(pattern: "你咁矮",           weight: 14, category: .appearance),
        .init(pattern: "你这么矮",         weight: 14, category: .appearance),
        .init(pattern: "你個鼻",           weight: 10, category: .appearance),
        .init(pattern: "你個樣",           weight: 12, category: .appearance),
        .init(pattern: "你塊面",           weight: 10, category: .appearance),
        .init(pattern: "你皮膚好差",       weight: 16, category: .appearance),
        .init(pattern: "你皮肤好差",       weight: 16, category: .appearance),
        .init(pattern: "你面色好差",       weight: 14, category: .appearance),
        .init(pattern: "你脸色不好",       weight: 14, category: .appearance),
        .init(pattern: "你啲痘痘",         weight: 14, category: .appearance, locale: .cantonese),
        .init(pattern: "你那些痘痘",       weight: 14, category: .appearance, locale: .mandarin),
        .init(pattern: "你冇身材",         weight: 18, category: .appearance),
        .init(pattern: "你身材不行",       weight: 16, category: .appearance),
        .init(pattern: "你個肚",           weight: 10, category: .appearance),
        .init(pattern: "你大肚腩",         weight: 14, category: .appearance),
        .init(pattern: "你肚腩好大",       weight: 14, category: .appearance),
        .init(pattern: "你大象腿",         weight: 14, category: .appearance),
        .init(pattern: "你條腿",           weight: 10, category: .appearance),
        .init(pattern: "你條腰",           weight: 10, category: .appearance),
        .init(pattern: "你瘦咗",           weight: 10, category: .appearance),
        .init(pattern: "你瘦了",           weight: 10, category: .appearance),
        .init(pattern: "你睇下人哋",       weight: 14, category: .appearance),
        .init(pattern: "你看看人家",       weight: 14, category: .appearance),
        .init(pattern: "人哋女朋友幾靚",   weight: 18, category: .appearance, locale: .cantonese),
        .init(pattern: "人家女朋友多漂亮", weight: 18, category: .appearance, locale: .mandarin),
        .init(pattern: "你睇下人哋女友",   weight: 18, category: .appearance, locale: .cantonese),
        .init(pattern: "你看看别人女友",   weight: 18, category: .appearance, locale: .mandarin),
        .init(pattern: "一啲都唔靚",       weight: 14, category: .appearance),
        .init(pattern: "一点都不可爱",     weight: 14, category: .appearance),
        .init(pattern: "唔識打扮",         weight: 14, category: .appearance, locale: .cantonese),
        .init(pattern: "不会打扮",         weight: 14, category: .appearance, locale: .mandarin),

        // ─── Guilt-tripping ─────────────────────────────────────────────
        .init(pattern: "我為你付出咁多",   weight: 22, category: .guilt),
        .init(pattern: "我为你付出这么多", weight: 22, category: .guilt),
        .init(pattern: "你對得起我咩",     weight: 20, category: .guilt),
        .init(pattern: "你对得起我吗",     weight: 20, category: .guilt),
        .init(pattern: "我為咗你",         weight: 20, category: .guilt),
        .init(pattern: "我为了你",         weight: 20, category: .guilt),
        .init(pattern: "我都係為你好",     weight: 22, category: .guilt),
        .init(pattern: "我都是为你好",     weight: 22, category: .guilt),
        .init(pattern: "如果唔係為咗你",   weight: 22, category: .guilt),
        .init(pattern: "要不是为了你",     weight: 22, category: .guilt),
        .init(pattern: "你知唔知我幾辛苦", weight: 20, category: .guilt),
        .init(pattern: "你知不知我多辛苦", weight: 20, category: .guilt),
        .init(pattern: "你知唔知我幾難受", weight: 20, category: .guilt),
        .init(pattern: "你知不知道我多難受", weight: 20, category: .guilt),
        .init(pattern: "你令我好失望",     weight: 18, category: .guilt),
        .init(pattern: "你让我很失望",     weight: 18, category: .guilt),
        .init(pattern: "我為你犧牲",       weight: 22, category: .guilt),
        .init(pattern: "我为你牺牲",       weight: 22, category: .guilt),
        .init(pattern: "我放棄咗好多",     weight: 20, category: .guilt),
        .init(pattern: "我放弃了很多",     weight: 20, category: .guilt),
        .init(pattern: "我為你喊",         weight: 18, category: .guilt),
        .init(pattern: "我为你哭",         weight: 18, category: .guilt),
        .init(pattern: "你欠我",           weight: 18, category: .guilt),
        .init(pattern: "你欠咗我",         weight: 18, category: .guilt),
        .init(pattern: "你係咪覺得我好煩", weight: 18, category: .guilt),
        .init(pattern: "你是不是觉得我烦", weight: 18, category: .guilt),
        .init(pattern: "我走啦你開心未",   weight: 18, category: .guilt, locale: .cantonese),
        .init(pattern: "我走了你开心了吧", weight: 18, category: .guilt, locale: .mandarin),

        // ─── Conditional love ───────────────────────────────────────────
        .init(pattern: "如果你愛我",       weight: 22, category: .conditional),
        .init(pattern: "如果你爱我",       weight: 22, category: .conditional),
        .init(pattern: "你愛我就應該",     weight: 24, category: .conditional),
        .init(pattern: "你爱我就该",       weight: 24, category: .conditional),
        .init(pattern: "真心愛我嘅話",     weight: 22, category: .conditional),
        .init(pattern: "真心爱我的话",     weight: 22, category: .conditional),
        .init(pattern: "你做到先算",       weight: 18, category: .conditional),
        .init(pattern: "你做到才算",       weight: 18, category: .conditional),
        .init(pattern: "你做到我就",       weight: 18, category: .conditional),
        .init(pattern: "你做到了我就",     weight: 18, category: .conditional),
        .init(pattern: "你愛我就唔會",     weight: 22, category: .conditional, locale: .cantonese),
        .init(pattern: "你爱我就不会",     weight: 22, category: .conditional, locale: .mandarin),
        .init(pattern: "如果你唔愛我",     weight: 20, category: .conditional, locale: .cantonese),
        .init(pattern: "如果你不爱我",     weight: 20, category: .conditional, locale: .mandarin),
        .init(pattern: "唔愛我就算",       weight: 18, category: .conditional, locale: .cantonese),
        .init(pattern: "不爱就算了",       weight: 18, category: .conditional, locale: .mandarin),

        // ─── Ownership / control ────────────────────────────────────────
        .init(pattern: "你係我嘅",         weight: 24, category: .ownership),
        .init(pattern: "你是我的",         weight: 18, category: .ownership),
        .init(pattern: "唔准你",           weight: 20, category: .ownership),
        .init(pattern: "不准你",           weight: 20, category: .ownership),
        .init(pattern: "我要你",           weight: 16, category: .ownership),
        .init(pattern: "我要你",           weight: 16, category: .ownership),
        .init(pattern: "你要聽我講",       weight: 14, category: .ownership),
        .init(pattern: "你要听我的",       weight: 14, category: .ownership),
        .init(pattern: "你要聽我話",       weight: 14, category: .ownership, locale: .cantonese),
        .init(pattern: "你要听话",         weight: 14, category: .ownership, locale: .mandarin),
        .init(pattern: "我話事",           weight: 18, category: .ownership),
        .init(pattern: "我说了算",         weight: 18, category: .ownership),
        .init(pattern: "你部電話畀我睇",   weight: 22, category: .ownership),
        .init(pattern: "你手机给我看",     weight: 22, category: .ownership),
        .init(pattern: "把密碼畀我",       weight: 24, category: .ownership),
        .init(pattern: "把密码给我",       weight: 24, category: .ownership),
        .init(pattern: "你定位開住",       weight: 22, category: .ownership),
        .init(pattern: "你定位开着",       weight: 22, category: .ownership),
        .init(pattern: "你係咪聽話",       weight: 16, category: .ownership),
        .init(pattern: "你听不听话",       weight: 16, category: .ownership),
        .init(pattern: "做個聽話嘅",       weight: 16, category: .ownership),
        .init(pattern: "做个听话的",       weight: 16, category: .ownership),
        .init(pattern: "你去邊都要話我知", weight: 18, category: .ownership, locale: .cantonese),
        .init(pattern: "你去哪都要告诉我", weight: 18, category: .ownership, locale: .mandarin),
        .init(pattern: "你通信錄畀我睇",   weight: 24, category: .ownership, locale: .cantonese),
        .init(pattern: "你通讯录给我看",   weight: 24, category: .ownership, locale: .mandarin),
        .init(pattern: "你著咩要畀我揀",   weight: 16, category: .ownership, locale: .cantonese),
        .init(pattern: "你穿什么要给我选", weight: 16, category: .ownership, locale: .mandarin),

        // ─── Isolation ──────────────────────────────────────────────────
        .init(pattern: "唔好同佢哋玩",     weight: 22, category: .isolation),
        .init(pattern: "别跟他们玩",       weight: 22, category: .isolation),
        .init(pattern: "你朋友冇用",       weight: 22, category: .isolation),
        .init(pattern: "你朋友没用",       weight: 22, category: .isolation),
        .init(pattern: "你屋企人都唔識嘢", weight: 22, category: .isolation),
        .init(pattern: "你家人不懂事",     weight: 22, category: .isolation),
        .init(pattern: "你淨係識我先得",   weight: 22, category: .isolation),
        .init(pattern: "你只能跟我",       weight: 22, category: .isolation),
        .init(pattern: "唔好見佢",         weight: 20, category: .isolation),
        .init(pattern: "不许见他",         weight: 20, category: .isolation),
        .init(pattern: "你成日同朋友出",   weight: 18, category: .isolation),
        .init(pattern: "你老跟朋友出",     weight: 18, category: .isolation),
        .init(pattern: "少啲同佢哋來往",   weight: 18, category: .isolation, locale: .cantonese),
        .init(pattern: "少跟他们来往",     weight: 18, category: .isolation, locale: .mandarin),
        .init(pattern: "我唔鍾意你啲朋友", weight: 18, category: .isolation, locale: .cantonese),
        .init(pattern: "我不喜欢你朋友",   weight: 18, category: .isolation, locale: .mandarin),
        .init(pattern: "有咩同我講就得",   weight: 12, category: .isolation),
        .init(pattern: "有事跟我说就行",   weight: 12, category: .isolation),

        // ─── Threat / coercion ──────────────────────────────────────────
        .init(pattern: "離開我你就死",     weight: 32, category: .threat),
        .init(pattern: "离开我你就死",     weight: 32, category: .threat),
        .init(pattern: "我會搞死你",       weight: 32, category: .threat),
        .init(pattern: "我会搞死你",       weight: 32, category: .threat),
        .init(pattern: "唔好迫我",         weight: 20, category: .threat),
        .init(pattern: "不要逼我",         weight: 20, category: .threat),
        .init(pattern: "你再迫我",         weight: 22, category: .threat, locale: .cantonese),
        .init(pattern: "你再逼我",         weight: 22, category: .threat, locale: .mandarin),
        .init(pattern: "我會自殘",         weight: 28, category: .threat),
        .init(pattern: "我会自残",         weight: 28, category: .threat),
        .init(pattern: "我去死畀你睇",     weight: 30, category: .threat),
        .init(pattern: "我死给你看",       weight: 30, category: .threat),
        .init(pattern: "我跳樓",           weight: 28, category: .threat),
        .init(pattern: "我跳楼",           weight: 28, category: .threat),
        .init(pattern: "你唔聽我就",       weight: 22, category: .threat),
        .init(pattern: "你不听我就",       weight: 22, category: .threat),
        .init(pattern: "後果自負",         weight: 22, category: .threat),
        .init(pattern: "后果自负",         weight: 22, category: .threat),
        .init(pattern: "你再嘈",           weight: 20, category: .threat, locale: .cantonese, severity: .high),
        .init(pattern: "你再吵",           weight: 20, category: .threat, locale: .mandarin, severity: .high),
        .init(pattern: "我唔知會做啲咩",   weight: 26, category: .threat, locale: .cantonese, severity: .critical),
        .init(pattern: "我不知道会做什么", weight: 26, category: .threat, locale: .mandarin, severity: .critical),
        .init(pattern: "你唔好後悔",       weight: 22, category: .threat),
        .init(pattern: "你不要后悔",       weight: 22, category: .threat),

        // ─── DARVO / blame-shifting ─────────────────────────────────────
        .init(pattern: "係你逼我嘅",       weight: 26, category: .blameShifting),
        .init(pattern: "是你逼我的",       weight: 26, category: .blameShifting),
        .init(pattern: "都係你嘅錯",       weight: 22, category: .blameShifting),
        .init(pattern: "都是你的错",       weight: 22, category: .blameShifting),
        .init(pattern: "你自己諗下",       weight: 14, category: .blameShifting),
        .init(pattern: "你自己想想",       weight: 14, category: .blameShifting),
        .init(pattern: "我都係因為你",     weight: 20, category: .blameShifting),
        .init(pattern: "我都是因为你",     weight: 20, category: .blameShifting),
        .init(pattern: "唔係我嘅問題",     weight: 14, category: .blameShifting),
        .init(pattern: "不是我的问题",     weight: 14, category: .blameShifting),
        .init(pattern: "你先發脾氣",       weight: 18, category: .blameShifting),
        .init(pattern: "你先发脾气",       weight: 18, category: .blameShifting),
        .init(pattern: "你先咁樣",         weight: 14, category: .blameShifting),
        .init(pattern: "是你先的",         weight: 14, category: .blameShifting),
        .init(pattern: "你搞到我",         weight: 18, category: .blameShifting),
        .init(pattern: "你害我",           weight: 20, category: .blameShifting),
        .init(pattern: "你害到我",         weight: 20, category: .blameShifting, locale: .cantonese),
        .init(pattern: "是你害的",         weight: 20, category: .blameShifting, locale: .mandarin),
        .init(pattern: "你咁樣邊個受得你", weight: 16, category: .blameShifting, locale: .cantonese),
        .init(pattern: "你这样谁受得了你", weight: 16, category: .blameShifting, locale: .mandarin),

        // ─── Future-faking ──────────────────────────────────────────────
        .init(pattern: "之後再講",         weight: 12, category: .futureFaking),
        .init(pattern: "以后再说",         weight: 12, category: .futureFaking),
        .init(pattern: "等我準備好",       weight: 14, category: .futureFaking),
        .init(pattern: "等我准备好",       weight: 14, category: .futureFaking),
        .init(pattern: "遲啲娶你",         weight: 22, category: .futureFaking),
        .init(pattern: "以后娶你",         weight: 22, category: .futureFaking),
        .init(pattern: "我會畀你幸福",     weight: 14, category: .futureFaking),
        .init(pattern: "我会给你幸福",     weight: 14, category: .futureFaking),
        .init(pattern: "畀啲時間我",       weight: 14, category: .futureFaking),
        .init(pattern: "给我点时间",       weight: 14, category: .futureFaking),
        .init(pattern: "等有錢先",         weight: 16, category: .futureFaking),
        .init(pattern: "等有钱了再说",     weight: 16, category: .futureFaking),
        .init(pattern: "等我穩定咗先",     weight: 16, category: .futureFaking, locale: .cantonese),
        .init(pattern: "等我稳定了再说",   weight: 16, category: .futureFaking, locale: .mandarin),
        .init(pattern: "唔係唔結婚",       weight: 14, category: .futureFaking, locale: .cantonese),
        .init(pattern: "不是不结婚",       weight: 14, category: .futureFaking, locale: .mandarin),

        // ─── Love-bombing (excessive early intensity) ───────────────────
        .init(pattern: "你係我嘅靈魂伴侶", weight: 18, category: .loveBombing),
        .init(pattern: "你是我的灵魂伴侣", weight: 18, category: .loveBombing),
        .init(pattern: "我冇你唔得",       weight: 18, category: .loveBombing),
        .init(pattern: "我没你不行",       weight: 18, category: .loveBombing),
        .init(pattern: "今世只愛你一個",   weight: 16, category: .loveBombing),
        .init(pattern: "今生只爱你一个",   weight: 16, category: .loveBombing),
        .init(pattern: "我哋係命中註定",   weight: 16, category: .loveBombing),
        .init(pattern: "我们是命中注定",   weight: 16, category: .loveBombing),
        .init(pattern: "我從來未試過咁愛一個人", weight: 18, category: .loveBombing),
        .init(pattern: "我从来没这么爱过一个人", weight: 18, category: .loveBombing),
        .init(pattern: "你係我嘅天使",     weight: 16, category: .loveBombing),
        .init(pattern: "你是我的天使",     weight: 16, category: .loveBombing),

        // ─── Breadcrumbing / mixed signals ──────────────────────────────
        .init(pattern: "我唔知自己想點",   weight: 16, category: .breadcrumb),
        .init(pattern: "我不知道自己想怎样", weight: 16, category: .breadcrumb),
        .init(pattern: "睇下感覺啦",       weight: 14, category: .breadcrumb),
        .init(pattern: "看感觉吧",         weight: 14, category: .breadcrumb),
        .init(pattern: "我哋唔係情侶",     weight: 16, category: .breadcrumb),
        .init(pattern: "我们不是情侣",     weight: 16, category: .breadcrumb),
        .init(pattern: "你想多咗啦",       weight: 18, category: .breadcrumb),
        .init(pattern: "你想太多了",       weight: 18, category: .breadcrumb),
        .init(pattern: "睇下先啦",         weight: 12, category: .breadcrumb, locale: .cantonese),
        .init(pattern: "先看看吧",         weight: 12, category: .breadcrumb, locale: .mandarin),
        .init(pattern: "唔急嘅",           weight: 10, category: .breadcrumb),
        .init(pattern: "不着急",           weight: 10, category: .breadcrumb),

        // ─── Jealousy traps ─────────────────────────────────────────────
        .init(pattern: "我前度好過你",     weight: 22, category: .jealousy),
        .init(pattern: "我前任比你好",     weight: 22, category: .jealousy),
        .init(pattern: "我有人追緊",       weight: 18, category: .jealousy),
        .init(pattern: "有人在追我",       weight: 18, category: .jealousy),
        .init(pattern: "你睇下佢幾好",     weight: 16, category: .jealousy),
        .init(pattern: "你看人家多好",     weight: 16, category: .jealousy),
        .init(pattern: "你信唔信我搞佢",   weight: 22, category: .jealousy),
        .init(pattern: "你信不信我搞她",   weight: 22, category: .jealousy),
        .init(pattern: "你冇佢咁好",       weight: 16, category: .jealousy),
        .init(pattern: "你没她好",         weight: 16, category: .jealousy),
        .init(pattern: "我前度就唔會咁",   weight: 18, category: .jealousy, locale: .cantonese),
        .init(pattern: "我前任就不会这样", weight: 18, category: .jealousy, locale: .mandarin),
        .init(pattern: "你睇下人哋男朋友", weight: 18, category: .jealousy, locale: .cantonese),
        .init(pattern: "你看别人男朋友",   weight: 18, category: .jealousy, locale: .mandarin),

        // ─── Financial control ──────────────────────────────────────────
        .init(pattern: "你份糧畀我管",     weight: 24, category: .finance),
        .init(pattern: "你的工资我管",     weight: 24, category: .finance),
        .init(pattern: "你使錢要問我",     weight: 22, category: .finance),
        .init(pattern: "你花钱要问我",     weight: 22, category: .finance),
        .init(pattern: "你冇我邊有錢",     weight: 22, category: .finance),
        .init(pattern: "没有我你哪有钱",   weight: 22, category: .finance),
        .init(pattern: "你食我嘅住我嘅",   weight: 20, category: .finance),
        .init(pattern: "你吃我的住我的",   weight: 20, category: .finance),
        .init(pattern: "你唔准亂使錢",     weight: 20, category: .finance, locale: .cantonese),
        .init(pattern: "你不许乱花钱",     weight: 20, category: .finance, locale: .mandarin),
        .init(pattern: "你賺咁少",         weight: 18, category: .finance),
        .init(pattern: "你赚那么少",       weight: 18, category: .finance),

        // ─── Stonewalling / silent treatment ────────────────────────────
        .init(pattern: "我唔想再講",       weight: 12, category: .stonewall),
        .init(pattern: "我不想再说",       weight: 12, category: .stonewall),
        .init(pattern: "我冷靜下先",       weight: 10, category: .stonewall),
        .init(pattern: "我冷静一下先",     weight: 10, category: .stonewall),
        .init(pattern: "你自己諗清楚先嚟搵我", weight: 18, category: .stonewall),
        .init(pattern: "你自己想清楚再来找我", weight: 18, category: .stonewall),
        .init(pattern: "我唔理你",         weight: 12, category: .stonewall),
        .init(pattern: "我不理你",         weight: 12, category: .stonewall),
        .init(pattern: "你唔好煩我",       weight: 12, category: .stonewall),
        .init(pattern: "你别烦我",         weight: 12, category: .stonewall),

        // ─── English equivalents ────────────────────────────────────────
        .init(pattern: "you're overreacting",       weight: 22, category: .gaslighting),
        .init(pattern: "you are overreacting",      weight: 22, category: .gaslighting),
        .init(pattern: "you're too sensitive",      weight: 22, category: .gaslighting),
        .init(pattern: "you are too sensitive",     weight: 22, category: .gaslighting),
        .init(pattern: "stop being so dramatic",    weight: 20, category: .dismissive),
        .init(pattern: "you're imagining things",   weight: 22, category: .gaslighting),
        .init(pattern: "that never happened",       weight: 22, category: .gaslighting),
        .init(pattern: "i never said that",         weight: 22, category: .gaslighting),
        .init(pattern: "you're crazy",              weight: 24, category: .gaslighting),
        .init(pattern: "you are crazy",             weight: 24, category: .gaslighting),
        .init(pattern: "you're so dramatic",        weight: 20, category: .dismissive),
        .init(pattern: "you are so dramatic",       weight: 20, category: .dismissive),
        .init(pattern: "it's just a joke",          weight: 12, category: .dismissive),
        .init(pattern: "it was just a joke",        weight: 12, category: .dismissive),
        .init(pattern: "you're being ridiculous",   weight: 20, category: .gaslighting),
        .init(pattern: "no one will love you",      weight: 30, category: .negging),
        .init(pattern: "you're lucky to have me",   weight: 24, category: .negging),
        .init(pattern: "no one else would put up with you", weight: 28, category: .negging),
        .init(pattern: "you're so needy",           weight: 18, category: .negging),
        .init(pattern: "you're impossible to please", weight: 20, category: .negging),
        .init(pattern: "if you really loved me",    weight: 22, category: .conditional),
        .init(pattern: "look what you made me do",  weight: 26, category: .blameShifting),
        .init(pattern: "you forced me to",          weight: 24, category: .blameShifting),
        .init(pattern: "after all i've done for you", weight: 22, category: .guilt),
        .init(pattern: "i'll change i promise",     weight: 16, category: .futureFaking),
        .init(pattern: "give me your password",     weight: 24, category: .ownership),
        .init(pattern: "show me your phone",        weight: 18, category: .ownership),
        .init(pattern: "who's that guy",            weight: 16, category: .ownership),
        .init(pattern: "who were you with",         weight: 14, category: .ownership),
        .init(pattern: "don't talk to them anymore", weight: 22, category: .isolation),
        .init(pattern: "i'll kill myself",          weight: 30, category: .threat),
        .init(pattern: "i can't live without you",  weight: 18, category: .loveBombing),
        .init(pattern: "you're the only one who understands me", weight: 16, category: .loveBombing),
        .init(pattern: "we're soulmates",           weight: 16, category: .loveBombing),
        .init(pattern: "you look better without makeup", weight: 14, category: .appearance, locale: .english),
        .init(pattern: "you've let yourself go",    weight: 18, category: .appearance, locale: .english),
    ]

    // MARK: - Public API

    /// All phrase patterns, deduplicated. Used to bias the speech recogniser.
    static var allPatterns: [String] {
        Array(Set(phrases.map { $0.pattern }))
    }

    static func patterns(disabledCategories: Set<Category>) -> [String] {
        Array(Set(phrases
            .filter { !disabledCategories.contains($0.category) }
            .map { $0.pattern }))
    }

    /// Convenience: just the score.
    static func score(for transcript: String) -> Double {
        evaluate(transcript).score
    }

    /// Full evaluation, returning the score and the phrases that triggered it.
    static func evaluate(_ transcript: String, disabledCategories: Set<Category> = []) -> Result {
        guard !transcript.isEmpty else {
            return Result(score: 20, hits: [])
        }

        let normalised = Self.normalise(transcript)
        var hits: [Hit] = []
        var categoryWeights: [Category: [Double]] = [:]

        for phrase in phrases {
            guard !disabledCategories.contains(phrase.category) else { continue }

            let needle = Self.normalise(phrase.pattern)
            guard !needle.isEmpty else { continue }

            if normalised.contains(needle) {
                hits.append(Hit(phrase: phrase.pattern,
                                weight: phrase.weight,
                                category: phrase.category,
                                locale: phrase.locale,
                                severity: phrase.severity,
                                similarity: 1.0))
                categoryWeights[phrase.category, default: []].append(phrase.weight)
                continue
            }

            // Fuzzy match: scan windows of length |needle| ± 1 across the
            // transcript and keep the best match if similarity is high enough.
            if let (sim, _) = bestFuzzyWindow(needle: needle, in: normalised),
               sim >= fuzzyThreshold(for: needle) {
                hits.append(Hit(phrase: phrase.pattern,
                                weight: phrase.weight * sim,
                                category: phrase.category,
                                locale: phrase.locale,
                                severity: phrase.severity,
                                similarity: sim))
                categoryWeights[phrase.category, default: []].append(phrase.weight * sim)
            }
        }

        if hits.isEmpty {
            // Drift gently around the noise floor based on how much we've heard.
            let drift = min(Double(normalised.count) / 80.0, 6.0)
            return Result(score: 20 + drift, hits: [])
        }

        // Category-aware score curve calibration:
        //  - 1 medium-weight hit (≈20)        → ~75 (crosses medium alert threshold)
        //  - 2 medium-weight hits (≈40)       → ~95 (strong alert)
        //  - 1 strong hit (≈30)               → ~95 (single severe phrase triggers)
        //  - 3+ hits or any combination       → saturates toward PEAK
        // Multiple near-duplicate phrases in one category contribute mostly
        // through the strongest hit, so "你諗多咗啦" does not double-count just
        // because it also contains "你諗多咗".
        let contextMultiplier = contextMultiplier(for: normalised)
        let totalWeighted = categoryWeights.values.reduce(0) { total, weights in
            let sorted = weights.sorted(by: >)
            guard let strongest = sorted.first else { return total }
            let supporting = sorted.dropFirst().reduce(0, +) * 0.25
            return total + strongest + supporting
        } * contextMultiplier
        // Curve: 45 + total*1.6, clamped 30…130. The 45 base lifts single-hit
        // cases out of the noise floor; the 1.6 multiplier keeps 2 solid
        // hits comfortably above the alert threshold without inflating weak
        // fuzzy matches.
        let highConfidencePhraseScore = hits.contains {
            $0.similarity >= singlePhraseDetectionSimilarity
        } ? singlePhraseDetectionScore * contextMultiplier : 0
        let raw = max(45 + totalWeighted * 1.6, highConfidencePhraseScore)
        let score = min(max(raw, 30), 130)
        return Result(score: score, hits: hits)
    }

    private static func contextMultiplier(for normalised: String) -> Double {
        let reportingMarkers = [
            "佢話", "佢講", "有人話", "人哋話", "朋友話",
            "他说", "她说", "有人说", "朋友说",
            "討論", "讨论", "引用", "例子", "例如",
            "hesaid", "shesaid", "theysaid", "quote", "example"
        ]
        return reportingMarkers.contains { normalised.contains($0) } ? 0.55 : 1.0
    }

    // MARK: - Fuzzy matching internals

    /// Strip punctuation/whitespace/case so ASR variants like
    /// "你 諗 多 咗 啦！" still align with "你諗多咗".
    static func normalise(_ s: String) -> String {
        let lowered = s.lowercased()
        var out = ""
        out.reserveCapacity(lowered.count)
        for scalar in lowered.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            if CharacterSet.punctuationCharacters.contains(scalar) { continue }
            if CharacterSet.symbols.contains(scalar) { continue }
            out.unicodeScalars.append(scalar)
        }
        return out
    }

    /// Required similarity scales with length: very short phrases must be near-
    /// exact (ASR rarely fluffs 3 characters into a false hit), while longer
    /// phrases can tolerate more drift.
    private static func fuzzyThreshold(for needle: String) -> Double {
        let n = needle.count
        if n <= 3 { return 1.0 }    // exact only — too risky to fuzz short tokens
        if n <= 5 { return 0.74 }   // 1 char drift on a 4-char phrase
        if n <= 8 { return 0.78 }
        return 0.72
    }

    /// Slides a window of length `needle.count ± 1` across `hay` and returns
    /// the best similarity found together with the matched substring.
    private static func bestFuzzyWindow(needle: String, in hay: String) -> (Double, String)? {
        let needleChars = Array(needle)
        guard !needleChars.isEmpty, !hay.isEmpty else { return nil }

        let hayChars = Array(hay)
        let len = needleChars.count
        guard hayChars.count >= max(2, len - 1) else { return nil }

        var best: (Double, String)? = nil
        for delta in [-1, 0, 1] {
            let w = len + delta
            guard w >= 2, w <= hayChars.count else { continue }
            var i = 0
            while i + w <= hayChars.count {
                let slice = Array(hayChars[i..<(i + w)])
                let dist = Self.levenshtein(needleChars, slice)
                let sim = 1.0 - Double(dist) / Double(max(needleChars.count, slice.count))
                if best == nil || sim > best!.0 {
                    best = (sim, String(slice))
                }
                i += 1
            }
        }
        return best
    }

    /// Plain Levenshtein over Character arrays. Phrases are short, so the
    /// O(n·m) cost is negligible — we only ever fuzz-match within a 160-char
    /// transcript window.
    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
