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
    case models(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "当前翻译源还没填好密钥或地址"
        case .empty: return "没有可翻译的文本"
        case .http(let code, let body): return "翻译接口失败（\(code)）\(body.isEmpty ? "" : "：\(body.prefix(160))")"
        case .decode: return "翻译结果解析失败"
        case .appleUnavailable: return "Apple 翻译需要更新的系统语言包接口，当前请改用自定义 AI / DeepL / Google / 百度"
        case .models(let message): return message
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

    func key(engine: TranslatorKind, source: String, target: String, text: String, model: String, mode: String) -> String {
        "\(engine.rawValue)|\(mode)|\(model)|\(source)|\(target)|\(text)"
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
        let base = OpenAIEndpoint.normalizedBase(settings.openaiBaseURL)
        let model = settings.openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !base.isEmpty, !model.isEmpty else { throw TranslatorError.notConfigured }

        let target = LanguageOption.targets.first(where: { $0.id == settings.targetLanguage })?.title
            ?? settings.targetLanguage
        let prompt = settings.openaiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppSettings.defaultPrompt
            : settings.openaiPrompt
        let user = "目标语言：\(target)\n\n\(text)"
        let maxTokens = min(max(settings.openaiMaxTokens, 64), 1024)

        switch settings.openaiAPIMode {
        case .chat:
            return try await chatCompletions(
                base: base,
                key: key,
                model: model,
                prompt: prompt,
                user: user,
                maxTokens: maxTokens
            )
        case .responses:
            return try await responses(
                base: base,
                key: key,
                model: model,
                prompt: prompt,
                user: user,
                maxTokens: maxTokens
            )
        }
    }

    private func chatCompletions(
        base: String,
        key: String,
        model: String,
        prompt: String,
        user: String,
        maxTokens: Int
    ) async throws -> String {
        let url = OpenAIEndpoint.url(base: base, path: "/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 18
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        if let content = flattenContent(message?["content"]) {
            return content
        }
        if let text = choices?.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw TranslatorError.decode
    }

    private func responses(
        base: String,
        key: String,
        model: String,
        prompt: String,
        user: String,
        maxTokens: Int
    ) async throws -> String {
        let url = OpenAIEndpoint.url(base: base, path: "/responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 18
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_output_tokens": maxTokens,
            "instructions": prompt,
            "input": user
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let outputText = json?["output_text"] as? String, !outputText.isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let output = json?["output"] as? [[String: Any]] {
            var parts: [String] = []
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let text = block["text"] as? String {
                            parts.append(text)
                        } else if let text = (block["text"] as? [String: Any])?["value"] as? String {
                            parts.append(text)
                        }
                    }
                }
            }
            let joined = parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { return joined }
        }
        throw TranslatorError.decode
    }
}

enum OpenAIEndpoint {
    static func normalizedBase(_ raw: String) -> String {
        var base = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/chat/completions") {
            base = String(base.dropLast("/chat/completions".count))
        } else if base.hasSuffix("/responses") {
            base = String(base.dropLast("/responses".count))
        }
        return base
    }

    static func url(base: String, path: String) -> URL {
        URL(string: normalizedBase(base) + path)!
    }
}

enum OpenAIModelCatalog {
    static func fetch(baseURL: String, apiKey: String) async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = OpenAIEndpoint.normalizedBase(baseURL)
        guard !key.isEmpty, !base.isEmpty else { throw TranslatorError.notConfigured }
        var request = URLRequest(url: OpenAIEndpoint.url(base: base, path: "/models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let ids = parseModelIDs(data)
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        if unique.isEmpty {
            throw TranslatorError.models("上游没有返回模型列表，请检查地址和密钥")
        }
        return unique.sorted { lhs, rhs in
            let lChat = lhs.localizedCaseInsensitiveContains("gpt") || lhs.localizedCaseInsensitiveContains("chat")
            let rChat = rhs.localizedCaseInsensitiveContains("gpt") || rhs.localizedCaseInsensitiveContains("chat")
            if lChat != rChat { return lChat && !rChat }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}

private func parseModelIDs(_ data: Data) -> [String] {
    let object = try? JSONSerialization.jsonObject(with: data)
    if let json = object as? [String: Any] {
        if let rows = json["data"] as? [[String: Any]] {
            return rows.compactMap { row in
                (row["id"] as? String) ?? (row["name"] as? String)
            }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let rows = json["models"] as? [[String: Any]] {
            return rows.compactMap { row in
                (row["id"] as? String) ?? (row["name"] as? String)
            }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let names = json["data"] as? [String] {
            return names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
    }
    if let rows = object as? [[String: Any]] {
        return rows.compactMap { $0["id"] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    if let names = object as? [String] {
        return names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    return []
}

private func flattenContent(_ value: Any?) -> String? {
    if let text = value as? String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    if let parts = value as? [[String: Any]] {
        let joined = parts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
    return nil
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
