import Foundation
import CryptoKit

protocol Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String
    func translate(
        _ text: String,
        settings: AppSettings,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String
}

extension Translator {
    func translate(
        _ text: String,
        settings: AppSettings,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        let result = try await translate(text, settings: settings)
        onPartial?(result)
        return result
    }
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
        case .appleUnavailable: return "Apple 翻译需要 iOS 18，当前系统不可用。请改用百度 / 腾讯 / 自定义 AI"
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
        case .tencent: return TencentTranslator()
        case .vps: return AppleTranslator()
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
        let sign = Insecure.MD5.hash(data: Data((appID + text + salt + secret).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        var request = URLRequest(url: URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            ("q", text),
            ("from", baiduCode(settings.sourceLanguage)),
            ("to", baiduCode(settings.targetLanguage)),
            ("appid", appID),
            ("salt", salt),
            ("sign", sign)
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let code = baiduErrorCode(json), code != "52000" {
            if code == "52003" {
                return try await translateCloud(text, appID: appID, secret: secret, settings: settings)
            }
            throw TranslatorError.http(Int(code) ?? 400, baiduErrorMessage(code, json?["error_msg"] as? String))
        }
        let results = json?["trans_result"] as? [[String: Any]]
        let joined = results?.compactMap { $0["dst"] as? String }.joined(separator: "\n")
        guard let joined, !joined.isEmpty else { throw TranslatorError.decode }
        return joined
    }

    /// 开放平台 52003 时改走百度智能云机器翻译（API Key + Secret Key）。
    private func translateCloud(_ text: String, appID: String, secret: String, settings: AppSettings) async throws -> String {
        var tokenRequest = URLRequest(url: URL(string: "https://aip.baidubce.com/oauth/2.0/token")!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.timeoutInterval = 12
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        tokenRequest.httpBody = formBody([
            ("grant_type", "client_credentials"),
            ("client_id", appID),
            ("client_secret", secret)
        ])
        let (tokenData, tokenResponse) = try await URLSession.shared.data(for: tokenRequest)
        try throwIfNeeded(tokenResponse, tokenData)
        let tokenJSON = try JSONSerialization.jsonObject(with: tokenData) as? [String: Any]
        guard let token = tokenJSON?["access_token"] as? String, !token.isEmpty else {
            let err = (tokenJSON?["error_description"] as? String) ?? (tokenJSON?["error"] as? String)
            throw TranslatorError.http(52003, baiduErrorMessage("52003", err ?? "UNAUTHORIZED USER"))
        }
        var request = URLRequest(url: URL(string: "https://aip.baidubce.com/rpc/2.0/mt/texttrans/v1?access_token=\(token)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "from": baiduCode(settings.sourceLanguage),
            "to": baiduCode(settings.targetLanguage),
            "q": text
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error_msg"] as? String, !error.isEmpty {
            throw TranslatorError.http((json?["error_code"] as? Int) ?? 400, error)
        }
        let results = ((json?["result"] as? [String: Any])?["trans_result"] as? [[String: Any]])
        let joined = results?.compactMap { $0["dst"] as? String }.joined(separator: "\n")
        guard let joined, !joined.isEmpty else {
            throw TranslatorError.http(52003, baiduErrorMessage("52003", "UNAUTHORIZED USER"))
        }
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
        case "vi": return "vie"
        default: return id
        }
    }

    private func baiduErrorCode(_ json: [String: Any]?) -> String? {
        if let code = json?["error_code"] as? String { return code }
        if let code = json?["error_code"] as? Int { return String(code) }
        return nil
    }

    private func baiduErrorMessage(_ code: String, _ raw: String?) -> String {
        let mapped: String
        switch code {
        case "52001": mapped = "请求超时"
        case "52002": mapped = "系统错误"
        case "52003": mapped = "未授权。开放平台要开通「通用文本翻译」；若这是智能云的 API Key，已自动改走智能云接口"
        case "54000": mapped = "必填参数为空"
        case "54001": mapped = "签名错误，检查密钥是否贴对"
        case "54003": mapped = "访问频率超限，免费版大约 1 次/秒"
        case "54004": mapped = "账户余额不足"
        case "54005": mapped = "长文本请求过于频繁"
        case "58000": mapped = "手机出口 IP 不在百度控制台白名单"
        case "58001": mapped = "不支持的语言方向"
        case "58002": mapped = "服务已关闭"
        case "90107": mapped = "认证未通过或服务未开通"
        default: mapped = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
        }
        if let raw, !raw.isEmpty, raw != mapped {
            return "\(mapped)（\(code) \(raw)）"
        }
        return "\(mapped)（\(code)）"
    }
}

struct TencentTranslator: Translator {
    func translate(_ text: String, settings: AppSettings) async throws -> String {
        let secretId = settings.tencentSecretId.trimmingCharacters(in: .whitespacesAndNewlines)
        let secretKey = settings.tencentSecretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secretId.isEmpty, !secretKey.isEmpty else { throw TranslatorError.notConfigured }
        let payload: [String: Any] = [
            "SourceText": text,
            "Source": tencentCode(settings.sourceLanguage),
            "Target": tencentCode(settings.targetLanguage),
            "ProjectId": 0
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let timestamp = Int(Date().timeIntervalSince1970)
        let date = tencentDate(timestamp)
        let hashedBody = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let canonical = [
            "POST",
            "/",
            "",
            "content-type:application/json; charset=utf-8",
            "host:tmt.tencentcloudapi.com",
            "",
            "content-type;host",
            hashedBody
        ].joined(separator: "\n")
        let canonicalHash = SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
        let credentialScope = "\(date)/tmt/tc3_request"
        let stringToSign = "TC3-HMAC-SHA256\n\(timestamp)\n\(credentialScope)\n\(canonicalHash)"
        let secretDate = hmacString("TC3" + secretKey, date)
        let secretService = hmacData(secretDate, "tmt")
        let secretSigning = hmacData(secretService, "tc3_request")
        let signature = hmacHex(secretSigning, stringToSign)
        var request = URLRequest(url: URL(string: "https://tmt.tencentcloudapi.com")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 12
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("tmt.tencentcloudapi.com", forHTTPHeaderField: "Host")
        request.setValue("TextTranslate", forHTTPHeaderField: "X-TC-Action")
        request.setValue("2018-03-21", forHTTPHeaderField: "X-TC-Version")
        request.setValue("ap-guangzhou", forHTTPHeaderField: "X-TC-Region")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(
            "TC3-HMAC-SHA256 Credential=\(secretId)/\(credentialScope), SignedHeaders=content-type;host, Signature=\(signature)",
            forHTTPHeaderField: "Authorization"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(response, data)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = (json?["Response"] as? [String: Any])?["Error"] as? [String: Any],
           let message = error["Message"] as? String {
            throw TranslatorError.http(400, message)
        }
        let target = ((json?["Response"] as? [String: Any])?["TargetText"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let target, !target.isEmpty else { throw TranslatorError.decode }
        return target
    }

    private func tencentCode(_ id: String) -> String {
        switch id {
        case "auto": return "auto"
        case "zh-Hans": return "zh"
        case "zh-Hant": return "zh-TW"
        default: return id
        }
    }

    private func tencentDate(_ timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    private func hmacString(_ key: String, _ message: String) -> Data {
        hmacData(Data(key.utf8), message)
    }

    private func hmacData(_ key: Data, _ message: String) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key))
        return Data(mac)
    }

    private func hmacHex(_ key: Data, _ message: String) -> String {
        hmacData(key, message).map { String(format: "%02x", $0) }.joined()
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
        try await translate(text, settings: settings, onPartial: nil)
    }

    func translate(
        _ text: String,
        settings: AppSettings,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        let key = settings.openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = OpenAIEndpoint.normalizedBase(settings.openaiBaseURL)
        let model = settings.openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !base.isEmpty, !model.isEmpty else { throw TranslatorError.notConfigured }
        let target = LanguageOption.targets.first(where: { $0.id == settings.targetLanguage })?.title
            ?? settings.targetLanguage
        let prompt = settings.openaiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppSettings.defaultPrompt
            : settings.openaiPrompt
        var user = "目标语言：\(target)\n\n\(text)"
        if text.contains("【1】") {
            user += "\n\n原文用【1】【2】标了不同气泡。译文保留这些标记，一段对一段，不要合成一段。"
        }
        let maxTokens = min(max(settings.openaiMaxTokens, 64), 2048)
        switch settings.openaiAPIMode {
        case .chat:
            return try await chatCompletions(
                base: base,
                key: key,
                model: model,
                prompt: prompt,
                user: user,
                maxTokens: maxTokens,
                onPartial: onPartial
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
        maxTokens: Int,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        let url = OpenAIEndpoint.url(base: base, path: "/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        let payload: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var data = Data()
            for try await chunk in bytes {
                data.append(chunk)
            }
            try throwIfNeeded(response, data)
        }
        var assembled = ""
        var lastEmit = Date.distantPast
        for try await line in bytes.lines {
            try Task.checkCancellation()
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let delta = ((json["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])
            if let piece = flattenContent(delta?["content"]) {
                assembled += piece
                let now = Date()
                if now.timeIntervalSince(lastEmit) > 0.08 {
                    lastEmit = now
                    onPartial?(assembled)
                }
            }
        }
        let result = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { throw TranslatorError.decode }
        onPartial?(result)
        return result
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
        request.timeoutInterval = 45
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

private func formBody(_ fields: [(String, String)]) -> Data {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let encoded = fields.map { key, value in
        let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(k)=\(v)"
    }.joined(separator: "&")
    return Data(encoded.utf8)
}
