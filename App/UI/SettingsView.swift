import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var showRegionEditor = false
    @State private var showManualModel = false

    var body: some View {
        Form {
            Section {
                Picker("主题", selection: $session.settings.colorTheme) {
                    ForEach(AppColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .onChange(of: session.settings.colorTheme) { theme in
                    session.settings.appearanceStyle = theme.appearance
                }
            } header: {
                Label("外观", systemImage: "sparkles")
            } footer: {
                Text("磨砂玻璃会透出浅色层次；暖色偏 Claude，蓝白偏 Codex。")
            }

            Section("翻译源（可多选）") {
                ForEach(TranslatorKind.selectableCases) { kind in
                    translatorRow(kind)
                }
                if session.settings.activeTranslators.isEmpty {
                    Text("没勾选翻译源")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }

            credentialsSection

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
                Text("直播扩展只负责抓屏。滑动时会丢掉未完成的识别和翻译。自定义 AI 使用流式输出。Apple 翻译需要 iOS 18。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showRegionEditor) {
            RegionEditorView(region: $session.settings.customRegion)
        }
    }

    private func translatorRow(_ kind: TranslatorKind) -> some View {
        HStack(spacing: 12) {
            Button {
                session.settings.toggleTranslator(kind)
            } label: {
                Image(systemName: session.settings.isEnabled(kind) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(session.settings.isEnabled(kind) ? Color(hex: session.settings.colorHex(for: kind)) : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                if kind == .apple {
                    Text("需要 iOS 18")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hex: session.settings.colorHex(for: kind)) },
                    set: { newColor in
                        session.settings.setColor(HexColor.hex(fromSwiftUI: newColor), for: kind)
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 36, height: 28)
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        if session.settings.isEnabled(.baidu) {
            Section("百度") {
                TextField("百度 App ID", text: $session.settings.baiduAppID)
                    .autocapitalization(.none)
                SecureField("百度密钥", text: $session.settings.baiduSecret)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }
        }
        if session.settings.isEnabled(.tencent) {
            Section("腾讯云翻译") {
                TextField("SecretId", text: $session.settings.tencentSecretId)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                SecureField("SecretKey", text: $session.settings.tencentSecretKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }
        }
        if session.settings.isEnabled(.google) {
            Section("Google") {
                SecureField("Google API Key", text: $session.settings.googleAPIKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }
        }
        if session.settings.isEnabled(.deepl) {
            Section("DeepL") {
                SecureField("DeepL API Key", text: $session.settings.deeplAPIKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
            }
        }
        if session.settings.isEnabled(.openai) {
            Section("自定义 AI") {
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
                Text("Chat Completions 使用流式输出，避免上游 499。")
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
                Stepper(value: $session.settings.openaiMaxTokens, in: 128...2048, step: 64) {
                    Text("最大输出 \(session.settings.openaiMaxTokens) tokens")
                }
                TextEditor(text: $session.settings.openaiPrompt)
                    .frame(minHeight: 90)
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        self.init(HexColor.uiColor(from: hex))
    }
}
