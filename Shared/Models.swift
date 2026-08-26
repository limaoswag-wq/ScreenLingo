import Foundation
import CoreGraphics

enum RecognitionMode: String, Codable, CaseIterable, Identifiable {
    case smart
    case custom
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "智能"
        case .custom: return "自定义"
        case .full: return "全屏"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "游戏/视频对准字幕带，漫画对准画面中间一带"
        case .custom: return "只识别你圈出来的那一块"
        case .full: return "整帧送去 OCR，最全也最慢"
        }
    }

    var symbol: String {
        switch self {
        case .smart: return "sparkles"
        case .custom: return "crop"
        case .full: return "rectangle.dashed"
        }
    }
}

enum MangaLayout: String, Codable, CaseIterable, Identifiable {
    case japanese
    case korean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japanese: return "日漫"
        case .korean: return "韩漫"
        }
    }

    var subtitle: String {
        switch self {
        case .japanese: return "竖排气泡，右到左"
        case .korean: return "横排气泡，左到右"
        }
    }

    var symbol: String {
        switch self {
        case .japanese: return "text.justify.right"
        case .korean: return "text.alignleft"
        }
    }
}

enum TranslateScene: String, Codable, CaseIterable, Identifiable {
    case game
    case manga
    case video
    case reading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .game: return "游戏"
        case .manga: return "漫画"
        case .video: return "视频"
        case .reading: return "阅读"
        }
    }

    var subtitle: String {
        switch self {
        case .game: return "适合游戏对话和选项"
        case .manga: return "按气泡拆开，日漫中间一带从右往左读"
        case .video: return "适合字幕，横屏底部 / 竖屏顶部"
        case .reading: return "复制文本就会翻译，不用开直播"
        }
    }

    var symbol: String {
        switch self {
        case .game: return "gamecontroller.fill"
        case .manga: return "book.fill"
        case .video: return "play.rectangle.fill"
        case .reading: return "doc.on.clipboard.fill"
        }
    }
}

enum OCREngineKind: String, Codable, CaseIterable, Identifiable {
    case visionAccurate
    case visionFast
    case mlkit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visionAccurate: return "Apple 高精度"
        case .visionFast: return "Apple 快速"
        case .mlkit: return "ML Kit 竖排"
        }
    }

    var subtitle: String {
        switch self {
        case .visionAccurate: return "系统 Vision，横排更稳"
        case .visionFast: return "系统 Vision，更快"
        case .mlkit: return "本机日韩中模型，竖排更好"
        }
    }
}

enum TranslatorKind: String, Codable, CaseIterable, Identifiable {
    case baidu
    case tencent
    case openai
    case google
    case deepl
    case vps
    case apple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple 翻译"
        case .google: return "Google Translate"
        case .baidu: return "百度翻译"
        case .tencent: return "腾讯翻译"
        case .deepl: return "DeepL"
        case .openai: return "自定义 AI"
        case .vps: return "VPS 本地包"
        }
    }

    var selectable: Bool {
        switch self {
        case .baidu, .tencent, .openai: return true
        default: return false
        }
    }

    static var selectableCases: [TranslatorKind] {
        [.baidu, .tencent, .openai]
    }

    var shortTitle: String {
        switch self {
        case .baidu: return "百度"
        case .tencent: return "腾讯"
        case .openai: return "AI"
        case .google: return "Google"
        case .deepl: return "DeepL"
        case .vps: return "VPS"
        case .apple: return "Apple"
        }
    }

    var defaultHex: String {
        switch self {
        case .baidu: return "#3B82F6"
        case .tencent: return "#22C55E"
        case .openai: return "#EAB308"
        case .google: return "#EF4444"
        case .deepl: return "#14B8A6"
        case .vps: return "#A855F7"
        case .apple: return "#9CA3AF"
        }
    }
}

enum OpenAIAPIMode: String, Codable, CaseIterable, Identifiable {
    case chat
    case responses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat Completions"
        case .responses: return "Responses"
        }
    }

    var subtitle: String {
        switch self {
        case .chat: return "POST /v1/chat/completions，兼容大多数中转"
        case .responses: return "POST /v1/responses，OpenAI 新接口"
        }
    }
}

enum CaptionFontSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "特大"
        }
    }

    var sourcePoints: CGFloat {
        switch self {
        case .small: return 13
        case .medium: return 15
        case .large: return 17
        case .extraLarge: return 19
        }
    }

    var translatedPoints: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 18
        case .large: return 21
        case .extraLarge: return 24
        }
    }
}

enum AppColorTheme: String, Codable, CaseIterable, Identifiable {
    case frosted
    case claude
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frosted: return "磨砂玻璃"
        case .claude: return "暖色"
        case .codex: return "蓝白"
        }
    }

    var appearance: AppearanceStyle {
        self == .frosted ? .frosted : .solid
    }
}

enum AppearanceStyle: String, Codable, CaseIterable, Identifiable {
    case frosted
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frosted: return "磨砂玻璃"
        case .solid: return "纯色"
        }
    }
}

enum CaptionWindowSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    var canvas: CGSize {
        switch self {
        case .small: return CGSize(width: 320, height: 72)
        case .medium: return CGSize(width: 390, height: 96)
        case .large: return CGSize(width: 430, height: 132)
        }
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let title: String

    static let auto = LanguageOption(id: "auto", title: "自动")
    static let zhHans = LanguageOption(id: "zh-Hans", title: "简体中文")
    static let zhHant = LanguageOption(id: "zh-Hant", title: "繁体中文")
    static let en = LanguageOption(id: "en", title: "英语")
    static let ja = LanguageOption(id: "ja", title: "日语")
    static let ko = LanguageOption(id: "ko", title: "韩语")
    static let fr = LanguageOption(id: "fr", title: "法语")
    static let de = LanguageOption(id: "de", title: "德语")
    static let es = LanguageOption(id: "es", title: "西班牙语")
    static let ru = LanguageOption(id: "ru", title: "俄语")
    static let vi = LanguageOption(id: "vi", title: "越南语")
    static let th = LanguageOption(id: "th", title: "泰语")

    static let sources: [LanguageOption] = [
        .auto, .ja, .en, .ko, .zhHans, .zhHant, .fr, .de, .es, .ru, .vi, .th
    ]

    static let targets: [LanguageOption] = [
        .zhHans, .zhHant, .en, .ja, .ko, .fr, .de, .es, .ru, .vi, .th
    ]
}

struct OCRRegion: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let full = OCRRegion(x: 0, y: 0, width: 1, height: 1)

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func clamped() -> OCRRegion {
        var copy = self
        copy.width = min(max(width, 0.08), 1)
        copy.height = min(max(height, 0.06), 1)
        copy.x = min(max(x, 0), 1 - copy.width)
        copy.y = min(max(y, 0), 1 - copy.height)
        return copy
    }

    func pixelRect(in size: CGSize) -> CGRect {
        let r = clamped()
        return CGRect(
            x: r.x * size.width,
            y: r.y * size.height,
            width: r.width * size.width,
            height: r.height * size.height
        ).integral
    }
}

struct TextBox: Equatable {
    var text: String
    var boundingBox: CGRect
    var confidence: Float = 1
}

struct CaptionLine: Equatable, Identifiable {
    var engine: TranslatorKind
    var text: String
    var pending: Bool
    var error: String?
    var hex: String

    var id: String { engine.rawValue }

    var displayText: String {
        if let error, !error.isEmpty { return error }
        if pending && text.isEmpty { return "翻译中…" }
        return text
    }
}

struct FrameMeta: Codable {
    var width: Int
    var height: Int
    var timestamp: TimeInterval
    var orientation: Int
}

struct BroadcastState: Codable {
    var isBroadcasting: Bool
    var startedAt: TimeInterval?
}
