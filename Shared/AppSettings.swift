import Foundation

struct AppSettings: Codable, Equatable {
    var recognitionMode: RecognitionMode = .smart
    var translateScene: TranslateScene = .video
    var mangaLayout: MangaLayout = .japanese
    var ocrEngine: OCREngineKind = .visionFast
    var translator: TranslatorKind = .openai
    var enabledTranslators: [TranslatorKind] = []
    var translatorColors: [String: String] = [:]
    var sourceLanguage: String = LanguageOption.auto.id
    var targetLanguage: String = LanguageOption.zhHans.id
    var customRegion: OCRRegion = OCRRegion(x: 0.08, y: 0.72, width: 0.84, height: 0.22)
    var showSourceText: Bool = true
    var showRuby: Bool = false
    var captureInterval: Double = 0.6
    var captionFontSize: CaptionFontSize = .medium
    var captionWindowSize: CaptionWindowSize = .medium
    var appearanceStyle: AppearanceStyle = .frosted
    var colorTheme: AppColorTheme = .frosted

    var googleAPIKey: String = ""
    var baiduAppID: String = ""
    var baiduSecret: String = ""
    var tencentSecretId: String = ""
    var tencentSecretKey: String = ""
    var deeplAPIKey: String = ""
    var openaiBaseURL: String = "https://api.openai.com/v1"
    var openaiAPIKey: String = ""
    var openaiModel: String = "gpt-4o-mini"
    var openaiAPIMode: OpenAIAPIMode = .chat
    var openaiMaxTokens: Int = 512
    var openaiPrompt: String = AppSettings.defaultPrompt

    static let defaultPrompt = "把原文译成指定目标语言。只输出译文，不要解释，不要拼音，不要引号。保留换行。若原文有【1】【2】标记，译文里原样保留，一段对一段。"

    static let storageKey = "screenlingo.settings.v1"

    enum CodingKeys: String, CodingKey {
        case recognitionMode, translateScene, mangaLayout, ocrEngine, translator
        case enabledTranslators, translatorColors
        case sourceLanguage, targetLanguage, customRegion
        case showSourceText, showRuby, captureInterval
        case captionFontSize, captionWindowSize, appearanceStyle, colorTheme
        case googleAPIKey, baiduAppID, baiduSecret
        case tencentSecretId, tencentSecretKey, deeplAPIKey
        case openaiBaseURL, openaiAPIKey, openaiModel, openaiAPIMode
        case openaiMaxTokens, openaiPrompt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recognitionMode = try c.decodeIfPresent(RecognitionMode.self, forKey: .recognitionMode) ?? .smart
        translateScene = try c.decodeIfPresent(TranslateScene.self, forKey: .translateScene) ?? .video
        mangaLayout = try c.decodeIfPresent(MangaLayout.self, forKey: .mangaLayout) ?? .japanese
        ocrEngine = try c.decodeIfPresent(OCREngineKind.self, forKey: .ocrEngine) ?? .visionFast
        translator = try c.decodeIfPresent(TranslatorKind.self, forKey: .translator) ?? .openai
        enabledTranslators = (try c.decodeIfPresent([TranslatorKind].self, forKey: .enabledTranslators) ?? [])
            .filter(\.selectable)
        translatorColors = try c.decodeIfPresent([String: String].self, forKey: .translatorColors) ?? [:]
        sourceLanguage = try c.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? LanguageOption.auto.id
        targetLanguage = try c.decodeIfPresent(String.self, forKey: .targetLanguage) ?? LanguageOption.zhHans.id
        customRegion = try c.decodeIfPresent(OCRRegion.self, forKey: .customRegion)
            ?? OCRRegion(x: 0.08, y: 0.72, width: 0.84, height: 0.22)
        showSourceText = try c.decodeIfPresent(Bool.self, forKey: .showSourceText) ?? true
        showRuby = try c.decodeIfPresent(Bool.self, forKey: .showRuby) ?? false
        captureInterval = try c.decodeIfPresent(Double.self, forKey: .captureInterval) ?? 0.6
        captionFontSize = try c.decodeIfPresent(CaptionFontSize.self, forKey: .captionFontSize) ?? .medium
        captionWindowSize = try c.decodeIfPresent(CaptionWindowSize.self, forKey: .captionWindowSize) ?? .medium
        appearanceStyle = try c.decodeIfPresent(AppearanceStyle.self, forKey: .appearanceStyle) ?? .frosted
        colorTheme = try c.decodeIfPresent(AppColorTheme.self, forKey: .colorTheme)
            ?? (appearanceStyle == .solid ? .claude : .frosted)
        googleAPIKey = try c.decodeIfPresent(String.self, forKey: .googleAPIKey) ?? ""
        baiduAppID = try c.decodeIfPresent(String.self, forKey: .baiduAppID) ?? ""
        baiduSecret = try c.decodeIfPresent(String.self, forKey: .baiduSecret) ?? ""
        tencentSecretId = try c.decodeIfPresent(String.self, forKey: .tencentSecretId) ?? ""
        tencentSecretKey = try c.decodeIfPresent(String.self, forKey: .tencentSecretKey) ?? ""
        deeplAPIKey = try c.decodeIfPresent(String.self, forKey: .deeplAPIKey) ?? ""
        openaiBaseURL = try c.decodeIfPresent(String.self, forKey: .openaiBaseURL) ?? "https://api.openai.com/v1"
        openaiAPIKey = try c.decodeIfPresent(String.self, forKey: .openaiAPIKey) ?? ""
        openaiModel = try c.decodeIfPresent(String.self, forKey: .openaiModel) ?? "gpt-4o-mini"
        openaiAPIMode = try c.decodeIfPresent(OpenAIAPIMode.self, forKey: .openaiAPIMode) ?? .chat
        openaiMaxTokens = try c.decodeIfPresent(Int.self, forKey: .openaiMaxTokens) ?? 512
        openaiPrompt = try c.decodeIfPresent(String.self, forKey: .openaiPrompt) ?? AppSettings.defaultPrompt
        if openaiMaxTokens < 64 { openaiMaxTokens = 512 }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(recognitionMode, forKey: .recognitionMode)
        try c.encode(translateScene, forKey: .translateScene)
        try c.encode(mangaLayout, forKey: .mangaLayout)
        try c.encode(ocrEngine, forKey: .ocrEngine)
        try c.encode(translator, forKey: .translator)
        try c.encode(enabledTranslators, forKey: .enabledTranslators)
        try c.encode(translatorColors, forKey: .translatorColors)
        try c.encode(sourceLanguage, forKey: .sourceLanguage)
        try c.encode(targetLanguage, forKey: .targetLanguage)
        try c.encode(customRegion, forKey: .customRegion)
        try c.encode(showSourceText, forKey: .showSourceText)
        try c.encode(showRuby, forKey: .showRuby)
        try c.encode(captureInterval, forKey: .captureInterval)
        try c.encode(captionFontSize, forKey: .captionFontSize)
        try c.encode(captionWindowSize, forKey: .captionWindowSize)
        try c.encode(appearanceStyle, forKey: .appearanceStyle)
        try c.encode(colorTheme, forKey: .colorTheme)
        try c.encode(googleAPIKey, forKey: .googleAPIKey)
        try c.encode(baiduAppID, forKey: .baiduAppID)
        try c.encode(baiduSecret, forKey: .baiduSecret)
        try c.encode(tencentSecretId, forKey: .tencentSecretId)
        try c.encode(tencentSecretKey, forKey: .tencentSecretKey)
        try c.encode(deeplAPIKey, forKey: .deeplAPIKey)
        try c.encode(openaiBaseURL, forKey: .openaiBaseURL)
        try c.encode(openaiAPIKey, forKey: .openaiAPIKey)
        try c.encode(openaiModel, forKey: .openaiModel)
        try c.encode(openaiAPIMode, forKey: .openaiAPIMode)
        try c.encode(openaiMaxTokens, forKey: .openaiMaxTokens)
        try c.encode(openaiPrompt, forKey: .openaiPrompt)
    }

    var activeTranslators: [TranslatorKind] {
        let unique = enabledTranslators.filter(\.selectable)
        var seen = Set<TranslatorKind>()
        return unique.filter { seen.insert($0).inserted }
    }

    func colorHex(for kind: TranslatorKind) -> String {
        translatorColors[kind.rawValue] ?? kind.defaultHex
    }

    mutating func setColor(_ hex: String, for kind: TranslatorKind) {
        translatorColors[kind.rawValue] = hex
    }

    mutating func toggleTranslator(_ kind: TranslatorKind) {
        guard kind.selectable else { return }
        if let index = enabledTranslators.firstIndex(of: kind) {
            enabledTranslators.remove(at: index)
        } else {
            enabledTranslators.append(kind)
        }
        translator = enabledTranslators.first ?? .openai
    }

    func isEnabled(_ kind: TranslatorKind) -> Bool {
        enabledTranslators.contains(kind)
    }

    func translatorIsConfigured(_ kind: TranslatorKind? = nil) -> Bool {
        switch kind ?? translator {
        case .apple:
            return false
        case .google:
            return !googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .baidu:
            return !baiduAppID.isEmpty && !baiduSecret.isEmpty
        case .tencent:
            return !tencentSecretId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !tencentSecretKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .deepl, .vps:
            return false
        case .openai:
            return !openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !openaiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !openaiModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func translatorIsConfigured() -> Bool {
        !activeTranslators.isEmpty && activeTranslators.contains(where: { translatorIsConfigured($0) })
    }
}
