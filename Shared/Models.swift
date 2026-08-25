import Foundation
import CoreGraphics

enum RecognitionMode: String, Codable, CaseIterable, Identifiable {
    case smart
    case custom
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "智能区域"
        case .custom: return "自定义区域"
        case .full: return "全屏"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "自动找字幕带或对话较密的一条横带"
        case .custom: return "只识别你圈出来的那一块"
        case .full: return "整帧送去 OCR，最慢也最全"
        }
    }
}

enum OCREngineKind: String, Codable, CaseIterable, Identifiable {
    case visionAccurate
    case visionFast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visionAccurate: return "Apple Vision · 精确"
        case .visionFast: return "Apple Vision · 快速"
        }
    }
}

enum TranslatorKind: String, Codable, CaseIterable, Identifiable {
    case apple
    case google
    case baidu
    case deepl
    case openai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple 翻译"
        case .google: return "Google Translate"
        case .baidu: return "百度翻译"
        case .deepl: return "DeepL"
        case .openai: return "自定义 AI（OpenAI 兼容）"
        }
    }

    var needsNetwork: Bool {
        self != .apple
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let title: String

    static let auto = LanguageOption(id: "auto", title: "自动检测")
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

/// Normalized rect in 0...1, relative to the captured frame.
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
    /// Vision bounding box, origin bottom-left, 0...1.
    var boundingBox: CGRect
}

struct TranslateResult: Equatable {
    var source: String
    var translated: String
    var boxes: [TextBox]
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
