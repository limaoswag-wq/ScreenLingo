import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @ObservedObject var session: TranslationSessionController
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    languageRow
                    startCard
                    resultCard
                    howTo
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("屏译")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(session: session)) {
                        Image(systemName: "gearshape")
                    }
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
        }
        .navigationViewStyle(.stack)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("实时屏幕翻译")
                .font(.title2.bold())
            Text("先选语言和翻译源，再开始直播。列表里选「屏译」。字幕走画中画小窗，切到别的 App 也能看。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var languageRow: some View {
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusDot
                Text(session.statusLine)
                    .font(.subheadline)
                Spacer()
            }
            if session.isRunning {
                Button(role: .destructive) {
                    session.stop()
                } label: {
                    Label("停止翻译", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    session.start()
                } label: {
                    Label("开始翻译会话", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            BroadcastStartButton(title: session.isBroadcasting ? "直播中 · 再点可停止" : "开始屏幕直播")
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("用相册图片试一次", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            if !session.settings.translatorIsConfigured() {
                Text("当前翻译源还没填密钥。打开右上角设置。")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusDot: some View {
        Circle()
            .fill(session.isBroadcasting ? Color.green : (session.isRunning ? Color.orange : Color.gray))
            .frame(width: 10, height: 10)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近一次结果").font(.headline)
            if let error = session.lastError, !error.isEmpty {
                Text(error).foregroundStyle(.orange).font(.footnote)
            }
            if !session.lastSource.isEmpty {
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("怎么用").font(.headline)
            labeled("1", "在设置里选 OCR 和翻译源，自定义 AI 填自己的 Key。")
            labeled("2", "点「开始翻译会话」，再点「开始屏幕直播」。")
            labeled("3", "系统列表里选「屏译」，等倒计时结束。")
            labeled("4", "切到游戏、漫画或视频。画中画小窗会出译文。")
            labeled("5", "识别范围可在设置里改成智能、自定义框或全屏。")
            Text("若列表里没有「屏译」，这是巨魔/系统没登记扩展，不是翻译逻辑坏了。那时仍可用相册试 OCR，或以后再接自己抓屏。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func labeled(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            Text(text).font(.subheadline)
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
