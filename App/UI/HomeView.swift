import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var photoItem: PhotosPickerItem?
    @State private var showRegionEditor = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    languageCard
                    sceneCard
                    areaCard
                    startCard
                    resultCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("屏译")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(session: session)) {
                        Image(systemName: "gearshape")
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

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语言")
                .font(.headline)
            HStack(spacing: 12) {
                languageMenu(
                    title: "原文",
                    selection: $session.settings.sourceLanguage,
                    options: LanguageOption.sources
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                languageMenu(
                    title: "译文",
                    selection: $session.settings.targetLanguage,
                    options: LanguageOption.targets
                )
            }
            Text("不同翻译服务支持的语言可能不一样")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
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
        .card()
    }

    private var areaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("翻译区域")
                    .font(.headline)
                Spacer()
                Button("编辑") { showRegionEditor = true }
                    .disabled(session.settings.recognitionMode != .custom)
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
            if session.settings.recognitionMode == .smart {
                Text("智能模式会自动识别游戏对话或视频字幕。区域不对再改成自定义。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.isBroadcasting ? Color.green : (session.isRunning ? Color.orange : Color.gray))
                    .frame(width: 10, height: 10)
                Text(session.statusLine)
                    .font(.subheadline)
                Spacer()
                if let ms = session.lastLatencyMS {
                    Text("\(ms)ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if session.isRunning {
                Button(role: .destructive) {
                    session.stop()
                } label: {
                    Text("停止")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    session.start()
                } label: {
                    Text("开始")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }

            if session.settings.translateScene != .reading {
                BroadcastStartButton(title: session.isBroadcasting ? "直播中" : "开始直播")
            } else {
                Text("阅读模式不用开直播。复制一段文字就会翻译。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("用相册图片试一次", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if !session.settings.translatorIsConfigured() {
                Text("需要先设置 API Key")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近一次结果").font(.headline)
            if let error = session.lastError, !error.isEmpty {
                Text(error).foregroundStyle(.orange).font(.footnote)
            }
            if session.settings.showSourceText, !session.lastSource.isEmpty {
                Text("原文").font(.caption).foregroundStyle(.secondary)
                Text(session.lastSource).textSelection(.enabled)
            }
            if !session.lastTranslated.isEmpty {
                Text("译文").font(.caption).foregroundStyle(.secondary)
                Text(session.lastTranslated)
                    .font(.title3.weight(.semibold))
                    .textSelection(.enabled)
            }
            if session.lastSource.isEmpty && session.lastTranslated.isEmpty {
                Text("还没有识别结果。").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(options.first(where: { $0.id == selection.wrappedValue })?.title ?? selection.wrappedValue)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    func card() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
