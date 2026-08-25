import Foundation
import CryptoKit

protocol Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String
}

enum TranslatorError: LocalizedError {
    case notConfigured
    case empty
    case http(Int, String)
    case decode
    case appleUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "当前翻译源还没填好密钥或地址"
        case .empty: return "没有可翻译的文本"
        case .http(let code, let body): return "翻译接口失败（\(code)）\(body.isEmpty ? "" : "：\(body.prefix(120))")"
        case .decode: return "翻译结果解析失败"
        case .appleUnavailable: return "Apple 翻译需要更新的系统语言包接口，当前请改用自定义 AI / DeepL / Google / 百度"
        }
    }
}

enum TranslatorFactory {
    static func make(_ kind: TranslatorKind) -> Translator {
        switch kind {
        case .apple: return AppleTranslator()
        case .google: return GoogleTranslator()
        case .baidu: return BaiduTranslator()
        case .deepl: return DeepLTranslator()
        case .openai: return OpenAITranslator()
        }
    }
}

final class TranslationCache {
    private var map: [String: String] = [:]
    private let lock = NSLock()
    private let limit = 400

    func key(engine: TranslatorKind, source: String, target: String, text: String) -> String {
        "\(engine.rawValue)|\(source)|\(target)|\(text)"
    }

    func get(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return map[key]
    }

    func set(_ key: String, value: String) {
        lock.lock(); defer { lock.unlock() }
        if map.count >= limit {
            map.removeAll(keepingCapacity: true)
        }
        map[key] = value
    }
}

struct AppleTranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslatorError.empty }
        throw TranslatorError.appleUnavailable
    }
}

struct GoogleTranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let key = settings.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranslatorError.notConfigured }
        var comps = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "target", value: googleCode(settings.targetLanguage)),
            URLQueryItem(name: "format", value: "text"),
            URLQueryItem(name: "key", value: key)
        ]
        if settings.sourceLanguage != "auto" {
            comps.queryItems?.append(URLQueryItem(name: "source", value: googleCode(settings.sourceLanguage)))
        }
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let translations = ((json?["data"] as? [String: Any])?["translations"] as? [[String: Any]])
        guard let translated = translations?.first?["translatedText"] as? String else {
            throw TranslatorError.decode
        }
        return unescape(translated)
    }

    private func googleCode(_ id: String) -> String {
        switch id {
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        default: return id
        }
    }
}

struct BaiduTranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let appID = settings.baiduAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = settings.baiduSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty, !secret.isEmpty else { throw TranslatorError.notConfigured }
        let salt = String(Int.random(in: 10000...99999))
        let signSource = appID + text + salt + secret
        let sign = Insecure.MD5.hash(data: Data(signSource.utf8)).map { String(format: "%02x", $0) }.joined()
        var comps = URLComponents(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "from", value: baiduCode(settings.sourceLanguage)),
            URLQueryItem(name: "to", value: baiduCode(settings.targetLanguage)),
            URLQueryItem(name: "appid", value: appID),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign)
        ]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error_msg"] as? String {
            throw TranslatorError.http(400, error)
        }
        let results = json?["trans_result"] as? [[String: Any]]
        let joined = results?.compactMap { $0["dst"] as? String }.joined(separator: "\n")
        guard let joined, !joined.isEmpty else { throw TranslatorError.decode }
        return joined
    }

    private func baiduCode(_ id: String) -> String {
        switch id {
        case "auto": return "auto"
        case "zh-Hans": return "zh"
        case "zh-Hant": return "cht"
        case "ja": return "jp"
        case "ko": return "kor"
        case "fr": return "fra"
        case "es": return "spa"
        default: return id
        }
    }
}

struct DeepLTranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let key = settings.deeplAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TranslatorError.notConfigured }
        let free = key.lowercased().hasSuffix(":fx")
        let url = URL(string: free
            ? "https://api-free.deepl.com/v2/translate"
            : "https://api.deepl.com/v2/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        var body = "text=\(urlEncode(text))&target_lang=\(deeplCode(settings.targetLanguage))"
        if settings.sourceLanguage != "auto" {
            body += "&source_lang=\(deeplCode(settings.sourceLanguage))"
        }
        request.httpBody = Data(body.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let translations = json?["translations"] as? [[String: Any]]
        guard let translated = translations?.first?["text"] as? String else {
            throw TranslatorError.decode
        }
        return translated
    }

    private func deeplCode(_ id: String) -> String {
        switch id {
        case "zh-Hans", "zh-Hant": return "ZH"
        case "en": return "EN"
        case "ja": return "JA"
        case "ko": return "KO"
        case "fr": return "FR"
        case "de": return "DE"
        case "es": return "ES"
        case "ru": return "RU"
        default: return id.uppercased()
        }
    }
}

struct OpenAITranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let key = settings.openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var base = settings.openaiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard !key.isEmpty, !base.isEmpty else { throw TranslatorError.notConfigured }
        let url = URL(string: base + "/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let target = LanguageOption.targets.first(where: { $0.id == settings.targetLanguage })?.title
            ?? settings.targetLanguage
        let prompt = settings.openaiPrompt.isEmpty ? AppSettings.defaultPrompt : settings.openaiPrompt
        let payload: [String: Any] = [
            "model": settings.openaiModel,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": "目标语言：\(target)\n\n原文：\n\(text)"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        if let content = message?["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw TranslatorError.decode
    }
}

private func throwIfNeeded(_ response: URLResponse, _ data: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw TranslatorError.http(http.statusCode, body)
    }
}

private func unescape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
}

private func urlEncode(_ text: String) -> String {
    text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
}
