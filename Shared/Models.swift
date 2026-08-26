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
        case .smart: return "自动对准游戏对话或视频字幕带"
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
        case .manga: return "适合靠近屏幕中部的气泡"
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visionAccurate: return "高精度"
        case .visionFast: return "快速"
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
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        case .extraLarge: return 28
        }
    }

    var translatedPoints: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 30
        case .extraLarge: return 36
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

enum OverlayBackground: String, Codable, CaseIterable, Identifiable {
    case solid
    case dim
    case ink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: return "实心"
        case .dim: return "半透明"
        case .ink: return "近透明"
        }
    }
}

enum CaptionWindowSize: String, Codable, CaseIterable, Identifiable {
    case compact
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "紧凑"
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    var width: CGFloat {
        switch self {
        case .compact: return 520
        case .small: return 580
        case .medium: return 640
        case .large: return 760
        }
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let title: String

    static let auto = LanguageOption(id: "auto", title: "自动")
    static let zhHans = LanguageOption(id: "zh-Hans", title: "简体中文")
    static let zhHant = LanguageOption(id: "zh-Hant", title: "繁体中文")
    static let en = LanguageOption(id: "en", title: "English")
    static let ja = LanguageOption(id: "ja", title: "日本語")
    static let ko = LanguageOption(id: "ko", title: "한국어")
    static let fr = LanguageOption(id: "fr", title: "Français")
    static let de = LanguageOption(id: "de", title: "Deutsch")
    static let es = LanguageOption(id: "es", title: "Español")
    static let ru = LanguageOption(id: "ru", title: "Русский")
    static let vi = LanguageOption(id: "vi", title: "Tiếng Việt")
    static let th = LanguageOption(id: "th", title: "ไทย")

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
