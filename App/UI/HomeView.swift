import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var photoItem: PhotosPickerItem?
    @State private var showRegionEditor = false

    private var appearance: AppearanceStyle { session.settings.appearanceStyle }

    var body: some View {
        NavigationView {
            ZStack {
                canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        languageCard
                        sceneCard
                        areaCard
                        startCard
                        resultCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("屏译")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(session: session)) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
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

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语言")
                .font(.headline)
            HStack(spacing: 12) {
                languageMenu(
                    title: "识别",
                    selection: $session.settings.sourceLanguage,
                    options: LanguageOption.sources
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                languageMenu(
                    title: "翻译成",
                    selection: $session.settings.targetLanguage,
                    options: LanguageOption.targets
                )
            }
            Text("默认自动识别，译成简体中文。可改成日语、韩语、英语等。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glass(appearance)
    }

    private var sceneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("翻译模式")
                .font(.headline)
            Picker("翻译模式", selection: $session.settings.translateScene) {
                ForEach(TranslateScene.allCases) { scene in
                    Text(scene.title).tag(scene)
                }
            }
            .pickerStyle(.segmented)
            Text(session.settings.translateScene.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .glass(appearance)
    }

    private var areaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("翻译区域")
                    .font(.headline)
                Spacer()
                if session.settings.recognitionMode == .custom {
                    Button("编辑") { showRegionEditor = true }
                }
            }
            Picker("翻译区域", selection: $session.settings.recognitionMode) {
                ForEach(RecognitionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(session.settings.recognitionMode.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .glass(appearance)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.isBroadcasting ? Color.green : (session.isRunning ? Color.orange : Color.gray.opacity(0.5)))
                    .frame(width: 9, height: 9)
                Text(session.statusLine)
                    .font(.subheadline)
                Spacer()
                if let ms = session.lastLatencyMS {
                    Text("\(ms)ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !session.overlayHint.isEmpty {
                Text(session.overlayHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if session.settings.translateScene == .reading {
                if session.isRunning {
                    stopButton
                } else {
                    Button {
                        session.start()
                    } label: {
                        Text("开始翻译")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
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
                Text("用相册图片试一次")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PressableButtonStyle())

            if !session.settings.translatorIsConfigured() {
                Text("需要先设置 API Key")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .glass(appearance, breathing: session.isTranslating)
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            session.stop()
        } label: {
            Text("停止")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近一次结果").font(.headline)
            if let error = session.lastError, !error.isEmpty {
                Text(error).foregroundStyle(.orange).font(.footnote)
            }
            if session.settings.showSourceText, !session.lastSource.isEmpty {
                Text("识别").font(.caption).foregroundStyle(.secondary)
                Text(session.lastSource)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            if session.isTranslating && session.lastTranslated.isEmpty {
                Text("翻译中…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.secondary)
            } else if !session.lastTranslated.isEmpty {
                Text("译文").font(.caption).foregroundStyle(.secondary)
                Text(session.lastTranslated)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            if session.lastSource.isEmpty && session.lastTranslated.isEmpty {
                Text("还没有识别结果。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(appearance, breathing: session.isTranslating)
    }

    private func languageMenu(
        title: String,
        selection: Binding<String>,
        options: [LanguageOption]
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) { selection.wrappedValue = option.id }
            }
        } label: {
            GlassChip(
                title: title,
                value: options.first(where: { $0.id == selection.wrappedValue })?.title ?? selection.wrappedValue,
                appearance: appearance
            )
        }
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

private extension View {
    func glass(_ appearance: AppearanceStyle, breathing: Bool = false) -> some View {
        GlassCard(appearance: appearance, breathing: breathing) { self }
    }
}
