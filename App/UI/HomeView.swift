import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var showRegionEditor = false
    @State private var showSourcePicker = false
    @State private var showTargetPicker = false
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: AppearanceStyle { session.settings.colorTheme.appearance }
    private var palette: ThemePalette { AppTheme.palette(session.settings.colorTheme) }

    var body: some View {
        NavigationView {
            ZStack {
                canvas.ignoresSafeArea()
                palette.wash.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        welcome
                        languageCard
                        modeCard
                        translatorCard
                        ocrCard
                        startCard
                        resultCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "captions.bubble.fill")
                            .foregroundStyle(palette.ink)
                        Text("屏译")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(session: session)) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("设置")
                }
            }
            .background(
                PiPHostRepresentable(view: session.pipHostView)
                    .frame(width: 8, height: 8)
                    .opacity(0.01)
                    .allowsHitTesting(false),
                alignment: .bottomTrailing
            )
            .sheet(isPresented: $showRegionEditor) {
                RegionEditorView(region: $session.settings.customRegion)
            }
            .onChange(of: session.settings.sourceLanguage) { _ in
                applyOCRDefault(for: session.settings.translateScene, layout: session.settings.mangaLayout)
            }
            .sheet(isPresented: $showSourcePicker) {
                LanguagePickerSheet(
                    title: "识别语言",
                    selection: $session.settings.sourceLanguage,
                    options: LanguageOption.sources
                )
            }
            .sheet(isPresented: $showTargetPicker) {
                LanguagePickerSheet(
                    title: "翻译成",
                    selection: $session.settings.targetLanguage,
                    options: LanguageOption.targets
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    private var canvas: Color {
        colorScheme == .dark ? palette.canvasDark : Color(red: 0.97, green: 0.97, blue: 0.98)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.23, green: 0.51, blue: 1))
                Text("欢迎使用屏译")
                    .font(.title2.weight(.bold))
            }
            HStack {
                StatusBadge(
                    broadcasting: session.isBroadcasting,
                    running: session.isRunning,
                    translating: session.isTranslating
                )
                Spacer()
                if let ms = session.lastLatencyMS {
                    Text("\(ms)ms")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            Text(session.statusLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var languageCard: some View {
        HStack(spacing: 10) {
            Button { showSourcePicker = true } label: {
                languagePill(
                    flag: flag(for: session.settings.sourceLanguage),
                    title: LanguageOption.sources.first(where: { $0.id == session.settings.sourceLanguage })?.title ?? "自动"
                )
            }
            .buttonStyle(PressableButtonStyle())
            Image(systemName: "arrow.left.arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Button { showTargetPicker = true } label: {
                languagePill(
                    flag: flag(for: session.settings.targetLanguage),
                    title: LanguageOption.targets.first(where: { $0.id == session.settings.targetLanguage })?.title ?? "简体中文"
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func languagePill(flag: String, title: String) -> some View {
        HStack(spacing: 8) {
            Text(flag)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func flag(for id: String) -> String {
        switch id {
        case "auto": return "🌐"
        case "zh-Hans", "zh-Hant": return "🇨🇳"
        case "en": return "🇺🇸"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "es": return "🇪🇸"
        case "ru": return "🇷🇺"
        case "vi": return "🇻🇳"
        case "th": return "🇹🇭"
        default: return "🌐"
        }
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("翻译模式", value: session.settings.translateScene.title) {
                Menu {
                    ForEach(TranslateScene.allCases) { scene in
                        Button(scene.title) {
                            withAnimation(AppTheme.spring) {
                                session.settings.translateScene = scene
                                applyOCRDefault(for: scene, layout: session.settings.mangaLayout)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(session.settings.translateScene.title)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if session.settings.translateScene == .manga {
                HStack(spacing: 8) {
                    ForEach(MangaLayout.allCases) { layout in
                        Button {
                            withAnimation(AppTheme.spring) {
                                session.settings.mangaLayout = layout
                                applyOCRDefault(for: .manga, layout: layout)
                            }
                        } label: {
                            Text(layout.title)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(session.settings.mangaLayout == layout ? Color(red: 0.23, green: 0.51, blue: 1) : Color(red: 0.96, green: 0.96, blue: 0.97))
                                .foregroundStyle(session.settings.mangaLayout == layout ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                Text(session.settings.mangaLayout.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label(session.settings.recognitionMode.title + "识别", systemImage: "viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.settings.recognitionMode == .custom {
                    Button("重新选择区域") { showRegionEditor = true }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var translatorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("翻译源", value: translatorSummary) {
                NavigationLink(destination: SettingsView(session: session)) {
                    HStack(spacing: 4) {
                        Text(translatorSummary)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Text(session.settings.translatorIsConfigured() ? "已保存密钥，可直接开始" : "点右边去填写百度 / 腾讯 / AI 密钥")
                .font(.footnote)
                .foregroundStyle(session.settings.translatorIsConfigured() ? .secondary : Color.orange)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var translatorSummary: String {
        let names = session.settings.activeTranslators.map(\.shortTitle)
        return names.isEmpty ? "未选择" : names.joined(separator: " / ")
    }

    private var ocrCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("OCR", value: session.settings.ocrEngine.title) {
                Menu {
                    ForEach(OCREngineKind.allCases) { engine in
                        Button(engine.title) {
                            session.settings.ocrEngine = engine
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(session.settings.ocrEngine.title)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Text(session.settings.ocrEngine.subtitle + (MLKitOCR.isAvailable || session.settings.ocrEngine != .mlkit ? "" : "（本包未编进 ML Kit 时会回退 Apple）"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row<Value: View>(_ title: String, value: String, @ViewBuilder trailing: () -> Value) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            trailing()
        }
        .font(.body)
    }

    private func applyOCRDefault(for scene: TranslateScene, layout: MangaLayout) {
        let source = session.settings.sourceLanguage
        if scene == .manga, layout == .japanese, source == "ja" {
            session.settings.ocrEngine = .mlkit
        } else if session.settings.ocrEngine == .mlkit, source != "ja", source != "ko" {
            session.settings.ocrEngine = .visionAccurate
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.settings.translateScene == .reading {
                if session.isRunning {
                    readingStopButton
                } else {
                    Button(action: { session.start() }) {
                        Label("启动", systemImage: "play.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(red: 0.23, green: 0.51, blue: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                Text("阅读模式不用开直播。复制一段文字就会翻译。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if session.isBroadcasting || session.isRunning {
                broadcastStopButton
                if session.isBroadcasting {
                    Text("停止会同时关掉录屏和浮窗。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                BroadcastStartButton(title: "启动")
            }

            if session.settings.activeTranslators.isEmpty {
                Label("没勾选翻译源", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if !session.settings.translatorIsConfigured() {
                Label("需要先设置 API Key", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .glass(appearance, breathing: session.isTranslating)
    }

    private var readingStopButton: some View {
        Button(role: .destructive) {
            withAnimation(AppTheme.ease) { session.stop() }
        } label: {
            Label("停止", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var broadcastStopButton: some View {
        ZStack {
            Label("停止", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                .allowsHitTesting(false)
            BroadcastPicker(onTap: {
                withAnimation(AppTheme.ease) { session.stop() }
            })
            .opacity(0.02)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近一次结果", systemImage: "text.aligncenter")
                .font(.headline)
            if let error = session.lastError, !error.isEmpty {
                Text(error).foregroundStyle(.orange).font(.footnote)
            }
            if session.settings.showSourceText, !session.lastSource.isEmpty {
                captionBlock(title: "识别", text: session.lastSource, emphasized: false)
            }
            if session.captionLines.isEmpty && session.lastSource.isEmpty {
                Text("还没有识别结果。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ForEach(session.captionLines) { line in
                    Text(line.displayText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(HexColor.uiColor(from: line.hex)))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(appearance, breathing: session.isTranslating)
        .animation(AppTheme.ease, value: session.lastTranslated)
        .animation(AppTheme.ease, value: session.lastSource)
    }

    private func captionBlock(title: String, text: String, emphasized: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(emphasized ? .title3.weight(.semibold) : .body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }

}

struct LanguagePickerSheet: View {
    let title: String
    @Binding var selection: String
    let options: [LanguageOption]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(options) { option in
                Button {
                    withAnimation(AppTheme.ease) { selection = option.id }
                    dismiss()
                } label: {
                    HStack {
                        Text(option.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if option.id == selection {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private extension View {
    func glass(_ appearance: AppearanceStyle, breathing: Bool = false) -> some View {
        GlassCard(appearance: appearance, breathing: breathing) { self }
    }
}
