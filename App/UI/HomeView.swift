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
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        languageCard
                        areaCard
                        startCard
                        resultCard
                        sceneCard
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
        colorScheme == .dark ? palette.canvasDark : palette.canvasLight
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            Text(session.statusLine)
                .font(.title3.weight(.semibold))
            if !session.overlayHint.isEmpty {
                Text(session.overlayHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppTheme.ease, value: session.statusLine)
        .animation(AppTheme.ease, value: session.overlayHint)
        .glass(appearance, breathing: session.isTranslating)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("语言", systemImage: "globe")
                .font(.headline)
            HStack(spacing: 10) {
                Button { showSourcePicker = true } label: {
                    GlassChip(
                        title: "识别",
                        value: LanguageOption.sources.first(where: { $0.id == session.settings.sourceLanguage })?.title ?? "自动",
                        appearance: appearance,
                        symbol: "text.viewfinder"
                    )
                }
                .buttonStyle(PressableButtonStyle())
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Button { showTargetPicker = true } label: {
                    GlassChip(
                        title: "翻译成",
                        value: LanguageOption.targets.first(where: { $0.id == session.settings.targetLanguage })?.title ?? "简体中文",
                        appearance: appearance,
                        symbol: "character.bubble"
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .glass(appearance)
    }

    private var sceneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("翻译模式", systemImage: "square.grid.2x2.fill")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(TranslateScene.allCases) { scene in
                    Button {
                        withAnimation(AppTheme.spring) {
                            session.settings.translateScene = scene
                        }
                    } label: {
                        SelectableTile(
                            title: scene.title,
                            subtitle: scene.subtitle,
                            symbol: scene.symbol,
                            selected: session.settings.translateScene == scene,
                            appearance: appearance
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            if session.settings.translateScene == .manga {
                HStack(spacing: 8) {
                    ForEach(MangaLayout.allCases) { layout in
                        Button {
                            withAnimation(AppTheme.spring) {
                                session.settings.mangaLayout = layout
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: layout.symbol)
                                Text(layout.title)
                                    .font(.caption.weight(.semibold))
                                Text(layout.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(session.settings.mangaLayout == layout ? palette.ink : Color.primary.opacity(0.05))
                            .foregroundStyle(session.settings.mangaLayout == layout ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glass(appearance)
        .animation(AppTheme.spring, value: session.settings.translateScene)
        .animation(AppTheme.spring, value: session.settings.mangaLayout)
    }

    private var areaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("翻译区域", systemImage: "viewfinder")
                    .font(.headline)
                Spacer()
                if session.settings.recognitionMode == .custom {
                    Button {
                        showRegionEditor = true
                    } label: {
                        Label("编辑", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            HStack(spacing: 8) {
                ForEach(RecognitionMode.allCases) { mode in
                    Button {
                        withAnimation(AppTheme.spring) {
                            session.settings.recognitionMode = mode
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                            Text(mode.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(session.settings.recognitionMode == mode ? palette.ink : Color.primary.opacity(0.05))
                        .foregroundStyle(session.settings.recognitionMode == mode ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            Text(session.settings.recognitionMode.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .animation(AppTheme.ease, value: session.settings.recognitionMode)
        }
        .glass(appearance)
        .animation(AppTheme.spring, value: session.settings.recognitionMode)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.settings.translateScene == .reading {
                if session.isRunning {
                    stopButton
                } else {
                    Button(action: { session.start() }) {
                        Text("开始翻译")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(palette.ink)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                Text("阅读模式不用开直播。复制一段文字就会翻译。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if session.isBroadcasting {
                stopButton
            } else {
                BroadcastStartButton(title: "开始翻译")
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

    private var stopButton: some View {
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
