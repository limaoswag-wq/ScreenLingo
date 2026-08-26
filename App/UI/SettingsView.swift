import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var showRegionEditor = false
    @State private var credentialKind: TranslatorKind?

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

            Section {
                Toggle("只显示翻译结果", isOn: Binding(
                    get: { !session.settings.showSourceText },
                    set: { session.settings.showSourceText = !$0 }
                ))
                Picker("字体", selection: $session.settings.captionFontSize) {
                    ForEach(CaptionFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                Picker("宽度", selection: $session.settings.captionWindowSize) {
                    ForEach(CaptionWindowSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                Picker("字幕底", selection: $session.settings.overlayBackground) {
                    ForEach(OverlayBackground.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            } header: {
                Text("悬浮窗")
            } footer: {
                Text("高度会跟着原文和翻译行数收紧，不再留一大块空底。系统画中画窗口本身无法整窗透明。")
            }

            Section("说明") {
                Text("直播扩展只负责抓屏。滑动时会丢掉未完成的识别和翻译。自定义 AI 使用流式输出。点翻译源名称打开密钥卡片，只有保存才会写入。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showRegionEditor) {
            RegionEditorView(region: $session.settings.customRegion)
        }
        .sheet(item: $credentialKind) { kind in
            CredentialSheet(kind: kind, session: session)
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
            Button {
                credentialKind = kind
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .foregroundStyle(.primary)
                    Text(session.settings.translatorIsConfigured(kind) ? "已保存密钥" : "点这里填写密钥")
                        .font(.caption)
                        .foregroundStyle(session.settings.translatorIsConfigured(kind) ? Color.secondary : Color.orange)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                ForEach(HexColor.presets, id: \.hex) { preset in
                    Button(preset.name) {
                        session.settings.setColor(preset.hex, for: kind)
                    }
                }
            } label: {
                Circle()
                    .fill(Color(hex: session.settings.colorHex(for: kind)))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
            }
        }
    }
}

private struct CredentialSheet: View {
    let kind: TranslatorKind
    @ObservedObject var session: TranslationSessionController
    @Environment(\.dismiss) private var dismiss

    @State private var apiID = ""
    @State private var apiKey = ""
    @State private var openaiMode: OpenAIAPIMode = .chat
    @State private var openaiModel = ""
    @State private var openaiMaxTokens = 512
    @State private var openaiPrompt = ""
    @State private var showManualModel = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(kind.title)
                            .font(.title3.weight(.semibold))
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        fieldCard(title: idLabel, hint: "API ID", text: $apiID, secret: false)
                        fieldCard(title: keyLabel, hint: "API Key", text: $apiKey, secret: true)

                        if kind == .openai {
                            openaiExtras
                        }
                    }
                    .padding(20)
                }
                Divider()
                HStack(spacing: 12) {
                    Button("取消") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button("保存") { save(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var openaiExtras: some View {
        Picker("请求接口", selection: $openaiMode) {
            ForEach(OpenAIAPIMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        Text("Chat Completions 使用流式输出，避免上游 499。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        if session.availableModels.isEmpty || showManualModel {
            fieldCard(title: "模型名", hint: "Model", text: $openaiModel, secret: false)
        } else {
            Picker("模型", selection: $openaiModel) {
                ForEach(session.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
        }
        Button {
            Task {
                await session.refreshModels(baseURL: apiID, apiKey: apiKey)
                if !session.availableModels.contains(openaiModel), let first = session.availableModels.first {
                    openaiModel = first
                }
            }
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
        .disabled(session.isLoadingModels || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if let message = session.modelListMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        Toggle("手动输入模型名", isOn: $showManualModel)
        Stepper(value: $openaiMaxTokens, in: 128...2048, step: 64) {
            Text("最大输出 \(openaiMaxTokens) tokens")
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("提示词")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $openaiPrompt)
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func fieldCard(title: String, hint: String, text: Binding<String>, secret: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if secret {
                SecureField(title, text: text)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                TextField(title, text: text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text(hint)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var idLabel: String {
        switch kind {
        case .baidu: return "百度 App ID"
        case .tencent: return "腾讯 SecretId"
        case .openai: return "API 地址"
        default: return "API ID"
        }
    }

    private var keyLabel: String {
        switch kind {
        case .baidu: return "百度密钥"
        case .tencent: return "腾讯 SecretKey"
        case .openai: return "API Key"
        default: return "API Key"
        }
    }

    private var hint: String {
        switch kind {
        case .baidu:
            return "开放平台用 APP ID + 密钥；如果这是智能云的 API Key，保存后会自动改走智能云接口。"
        case .tencent:
            return "腾讯云机器翻译的 SecretId 和 SecretKey。"
        case .openai:
            return "自定义 AI 的接口地址和密钥。点保存后才会写入，取消不改动。"
        default:
            return "点保存后才会写入，取消不改动。"
        }
    }

    private func load() {
        switch kind {
        case .baidu:
            apiID = session.settings.baiduAppID
            apiKey = session.settings.baiduSecret
        case .tencent:
            apiID = session.settings.tencentSecretId
            apiKey = session.settings.tencentSecretKey
        case .openai:
            apiID = session.settings.openaiBaseURL
            apiKey = session.settings.openaiAPIKey
            openaiMode = session.settings.openaiAPIMode
            openaiModel = session.settings.openaiModel
            openaiMaxTokens = session.settings.openaiMaxTokens
            openaiPrompt = session.settings.openaiPrompt
        default:
            break
        }
    }

    private func save() {
        switch kind {
        case .baidu:
            session.settings.baiduAppID = apiID.trimmingCharacters(in: .whitespacesAndNewlines)
            session.settings.baiduSecret = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        case .tencent:
            session.settings.tencentSecretId = apiID.trimmingCharacters(in: .whitespacesAndNewlines)
            session.settings.tencentSecretKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        case .openai:
            session.settings.openaiBaseURL = apiID.trimmingCharacters(in: .whitespacesAndNewlines)
            session.settings.openaiAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            session.settings.openaiAPIMode = openaiMode
            session.settings.openaiModel = openaiModel.trimmingCharacters(in: .whitespacesAndNewlines)
            session.settings.openaiMaxTokens = openaiMaxTokens
            session.settings.openaiPrompt = openaiPrompt
        default:
            break
        }
        if !session.settings.isEnabled(kind) {
            session.settings.toggleTranslator(kind)
        }
    }
}

private extension Color {
    init(hex: String) {
        self.init(HexColor.uiColor(from: hex))
    }
}
