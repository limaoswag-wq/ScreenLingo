import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var showRegionEditor = false

    var body: some View {
        Form {
            Section("识别") {
                Picker("OCR 引擎", selection: $session.settings.ocrEngine) {
                    ForEach(OCREngineKind.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                Picker("识别范围", selection: $session.settings.recognitionMode) {
                    ForEach(RecognitionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(session.settings.recognitionMode.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if session.settings.recognitionMode == .custom {
                    Button("编辑识别框") { showRegionEditor = true }
                }
                HStack {
                    Text("取帧间隔")
                    Slider(value: $session.settings.captureInterval, in: 0.4...2.0, step: 0.1)
                    Text(String(format: "%.1fs", session.settings.captureInterval))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Toggle("字幕里同时显示原文", isOn: $session.settings.showSourceText)
            }

            Section("翻译源") {
                Picker("引擎", selection: $session.settings.translator) {
                    ForEach(TranslatorKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                translatorFields
            }

            Section("说明") {
                Text("直播扩展只负责抓屏。OCR 和翻译都在本 App 里做，所以翻译源可以随便换。自定义 AI 填任何兼容 /v1/chat/completions 的地址即可，例如 OpenAI、Groq、DeepSeek、自建中转。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showRegionEditor) {
            RegionEditorView(region: $session.settings.customRegion)
        }
    }

    @ViewBuilder
    private var translatorFields: some View {
        switch session.settings.translator {
        case .apple:
            Text("使用系统语言包，适合离线。若提示不可用，请到系统设置下载对应语言，或换其他引擎。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .google:
            SecureField("Google API Key", text: $session.settings.googleAPIKey)
                .textContentType(.password)
                .autocapitalization(.none)
        case .baidu:
            TextField("百度 App ID", text: $session.settings.baiduAppID)
                .autocapitalization(.none)
            SecureField("百度密钥", text: $session.settings.baiduSecret)
                .textContentType(.password)
                .autocapitalization(.none)
        case .deepl:
            SecureField("DeepL API Key", text: $session.settings.deeplAPIKey)
                .textContentType(.password)
                .autocapitalization(.none)
            Text("免费 Key 一般以 :fx 结尾，会走 api-free.deepl.com。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .openai:
            TextField("API 地址", text: $session.settings.openaiBaseURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)
            SecureField("API Key", text: $session.settings.openaiAPIKey)
                .textContentType(.password)
                .autocapitalization(.none)
            TextField("模型名", text: $session.settings.openaiModel)
                .autocapitalization(.none)
            TextEditor(text: $session.settings.openaiPrompt)
                .frame(minHeight: 120)
        }
    }
}
