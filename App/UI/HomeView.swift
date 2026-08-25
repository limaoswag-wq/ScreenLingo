import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var photoItem: PhotosPickerItem?
    @State private var showRegionEditor = false
    @State private var showSourcePicker = false
    @State private var showTargetPicker = false
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: AppearanceStyle { session.settings.appearanceStyle }

    var body: some View {
        NavigationView {
            ZStack {
                canvas.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        languageCard
                        sceneCard
                        areaCard
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
                            .foregroundStyle(AppTheme.ink)
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
            .onChange(of: photoItem) { newValue in
                guard let newValue else { return }
                Task { await loadPhoto(newValue) }
            }
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
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
                : UIColor(red: 0.957, green: 0.957, blue: 0.961, alpha: 1)
        })
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
        }
        .glass(appearance)
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
                        .background(session.settings.recognitionMode == mode ? AppTheme.ink : Color.primary.opacity(0.05))
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
                            .background(AppTheme.ink)
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

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("用相册图片试一次", systemImage: "photo")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            if !session.settings.translatorIsConfigured() {
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
            if session.isTranslating && session.lastTranslated.isEmpty {
                HStack {
                    ProgressView()
                    Text("翻译中…")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
            } else if !session.lastTranslated.isEmpty {
                captionBlock(title: "译文", text: session.lastTranslated, emphasized: true)
            } else if session.lastSource.isEmpty {
                Text("还没有识别结果。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
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

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage
            else { return }
            if !session.isRunning { session.start() }
            await session.previewPhoto(cgImage)
        } catch {
            session.lastError = error.localizedDescription
        }
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
                                .foregroundStyle(AppTheme.ink)
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
