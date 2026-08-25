import Foundation

struct AppSettings: Codable, Equatable {
    var recognitionMode: RecognitionMode = .smart
    var ocrEngine: OCREngineKind = .visionAccurate
    var translator: TranslatorKind = .openai
    var sourceLanguage: String = LanguageOption.auto.id
    var targetLanguage: String = LanguageOption.zhHans.id
    var customRegion: OCRRegion = OCRRegion(x: 0.08, y: 0.72, width: 0.84, height: 0.22)
    var showSourceText: Bool = true
    var captureInterval: Double = 0.7

    var googleAPIKey: String = ""
    var baiduAppID: String = ""
    var baiduSecret: String = ""
    var deeplAPIKey: String = ""
    var openaiBaseURL: String = "https://api.openai.com/v1"
    var openaiAPIKey: String = ""
    var openaiModel: String = "gpt-4o-mini"
    var openaiPrompt: String = AppSettings.defaultPrompt

    static let defaultPrompt = """
    你是屏幕翻译器。把用户给出的原文翻译成指定目标语言。
    只返回译文，不要解释，不要拼音，不要引号包裹。
    保留原有换行。专有名词可保留原文。
    """

    static let storageKey = "screenlingo.settings.v1"
}

extension AppSettings {
    func translatorIsConfigured() -> Bool {
        switch translator {
        case .apple:
            return true
        case .google:
            return !googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .baidu:
            return !baiduAppID.isEmpty && !baiduSecret.isEmpty
        case .deepl:
            return !deeplAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openai:
            return !openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !openaiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
