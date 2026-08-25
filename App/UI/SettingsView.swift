import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var showRegionEditor = false
    @State private var showManualModel = false

    var body: some View {
        Form {
            Section {
                Picker("外观质感", selection: $session.settings.appearanceStyle) {
                    ForEach(AppearanceStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            } header: {
                Label("外观", systemImage: "sparkles")
            }

            Section("翻译服务") {
                Picker("引擎", selection: $session.settings.translator) {
                    ForEach(TranslatorKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                translatorFields
            }

            Section("识别") {
                Picker("OCR", selection: $session.settings.ocrEngine) {
                    ForEach(OCREngineKind.allCases) { engine in
                        Text(engine.title).tag(engine)
                    }
                }
                Picker("翻译区域", selection: $session.settings.recognitionMode) {
                    ForEach(RecognitionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if session.settings.recognitionMode == .custom {
                    Button("编辑识别框") { showRegionEditor = true }
                }
                HStack {
                    Text("取帧间隔")
                    Slider(value: $session.settings.captureInterval, in: 0.35...1.5, step: 0.05)
                    Text(String(format: "%.2fs", session.settings.captureInterval))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Section("UI") {
                Toggle("只显示翻译结果", isOn: Binding(
                    get: { !session.settings.showSourceText },
                    set: { session.settings.showSourceText = !$0 }
                ))
                Picker("字体大小", selection: $session.settings.captionFontSize) {
                    ForEach(CaptionFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                Picker("浮窗大小", selection: $session.settings.captionWindowSize) {
                    ForEach(CaptionWindowSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
            }

            Section("说明") {
                Text("直播扩展只负责抓屏。OCR 和翻译都在本 App 里做。自定义 AI 可切 Chat Completions 或 Responses，模型从上游 /v1/models 拉取。")
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
            Text("使用系统语言包。若提示不可用，请换其他引擎。")
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
                .disableAutocorrection(true)
            SecureField("API Key", text: $session.settings.openaiAPIKey)
                .textContentType(.password)
                .autocapitalization(.none)
            Picker("请求接口", selection: $session.settings.openaiAPIMode) {
                ForEach(OpenAIAPIMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Text(session.settings.openaiAPIMode.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if session.availableModels.isEmpty {
                TextField("模型名", text: $session.settings.openaiModel)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                Picker("模型", selection: $session.settings.openaiModel) {
                    ForEach(session.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            Button {
                Task { await session.refreshModels() }
            } label: {
                if session.isLoadingModels {
                    HStack {
                        ProgressView()
                        Text("正在获取模型列表")
                    }
                } else {
                    Text("从上游获取模型列表")
                }
            }
            .disabled(session.isLoadingModels || session.settings.openaiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let message = session.modelListMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle("手动输入模型名", isOn: $showManualModel)
            if showManualModel {
                TextField("模型名", text: $session.settings.openaiModel)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            Stepper(value: $session.settings.openaiMaxTokens, in: 64...1024, step: 64) {
                Text("最大输出 \(session.settings.openaiMaxTokens) tokens")
            }
            TextEditor(text: $session.settings.openaiPrompt)
                .frame(minHeight: 90)
        }
    }
}
