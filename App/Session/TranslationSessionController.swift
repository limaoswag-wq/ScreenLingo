import Foundation
import Combine
import UIKit
import CryptoKit

@MainActor
final class TranslationSessionController: ObservableObject {
    @Published var settings: AppSettings {
        didSet { store.saveSettings(settings) }
    }
    @Published var isRunning = false
    @Published var isBroadcasting = false
    @Published var lastSource = ""
    @Published var lastTranslated = ""
    @Published var lastError: String?
    @Published var statusLine = "未开始"
    @Published var lastLatencyMS: Int?
    @Published var availableModels: [String] = []
    @Published var isLoadingModels = false
    @Published var modelListMessage: String?

    private let store = AppGroupStore.shared
    private let ocr = OCREngine()
    private let cache = TranslationCache()
    private let pip = PiPCaptionController()
    private var timer: Timer?
    private var lastFrameDate: Date?
    private var lastTextHash = ""
    private var inFlight = false
    private var waitingTicks = 0
    private var pasteboardChangeCount = UIPasteboard.general.changeCount
    private var lastPaste = ""

    var pipHostView: UIView { pip.hostView }

    init() {
        settings = store.loadSettings()
        isBroadcasting = store.readBroadcasting()
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isBroadcasting = AppGroupStore.shared.readBroadcasting()
            }
        }
    }

    func start() {
        isRunning = true
        lastError = nil
        lastLatencyMS = nil
        waitingTicks = 0
        pasteboardChangeCount = UIPasteboard.general.changeCount
        statusLine = waitingMessage()
        SilentAudio.shared.start()
        pip.fontSize = settings.captionFontSize
        pip.windowSize = settings.captionWindowSize
        pip.update(source: "", translated: "等待屏幕画面…")
        pip.start()
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        pip.stop()
        SilentAudio.shared.stop()
        statusLine = "已停止"
    }

    func previewPhoto(_ image: CGImage) async {
        await process(image: image, force: true)
    }

    func refreshModels() async {
        guard settings.translator == .openai else { return }
        isLoadingModels = true
        modelListMessage = nil
        defer { isLoadingModels = false }
        do {
            let models = try await OpenAIModelCatalog.fetch(
                baseURL: settings.openaiBaseURL,
                apiKey: settings.openaiAPIKey
            )
            availableModels = models
            if !models.contains(settings.openaiModel), let first = models.first {
                settings.openaiModel = first
            }
            modelListMessage = "已获取 \(models.count) 个模型"
        } catch {
            modelListMessage = error.localizedDescription
        }
    }

    private func tick() async {
        isBroadcasting = store.readBroadcasting()
        pip.fontSize = settings.captionFontSize
        pip.windowSize = settings.captionWindowSize
        guard isRunning, !inFlight else { return }

        if settings.translateScene == .reading {
            await pollPasteboard()
            return
        }

        guard let modified = store.frameModificationDate() else {
            waitingTicks += 1
            statusLine = waitingMessage()
            return
        }
        if let lastFrameDate, modified <= lastFrameDate { return }
        guard let pair = store.readFrameImage() else {
            waitingTicks += 1
            statusLine = waitingMessage()
            return
        }
        lastFrameDate = modified
        waitingTicks = 0
        await process(image: pair.0, force: false)
    }

    private func pollPasteboard() async {
        let board = UIPasteboard.general
        guard board.changeCount != pasteboardChangeCount else { return }
        pasteboardChangeCount = board.changeCount
        guard let text = board.string else { return }
        let compact = ocr.compactForTranslation(text)
        guard compact != lastPaste, !compact.isEmpty else { return }
        lastPaste = compact
        inFlight = true
        await translateText(compact, force: true)
        inFlight = false
    }

    private func waitingMessage() -> String {
        if let error = store.directoryError {
            return error
        }
        if settings.translateScene == .reading {
            return "阅读模式：复制文本就会翻译"
        }
        if isBroadcasting {
            return "直播中，等待画面…"
        }
        return "点开始后，再点开始直播"
    }

    private func process(image: CGImage, force: Bool) async {
        inFlight = true
        defer { inFlight = false }
        do {
            let started = Date()
            let boxes = try await ocr.recognize(image: image, settings: settings)
            let source = ocr.joinedText(from: boxes, settings: settings)
            if source.isEmpty {
                statusLine = "这一帧没有识别到字"
                return
            }
            let hash = SHA256.hash(data: Data(source.utf8)).compactMap { String(format: "%02x", $0) }.joined()
            if !force, hash == lastTextHash, !lastTranslated.isEmpty {
                statusLine = "画面未变，沿用上次译文"
                return
            }
            lastTextHash = hash
            await translateText(source, ocrStarted: started)
        } catch {
            lastError = error.localizedDescription
            pip.update(
                source: settings.showSourceText ? lastSource : "",
                translated: lastTranslated,
                error: lastError
            )
            statusLine = lastError ?? "出错"
        }
    }

    private func translateText(_ source: String, force _: Bool = false, ocrStarted: Date = Date()) async {
        lastSource = source
        if !settings.translatorIsConfigured() {
            lastError = TranslatorError.notConfigured.localizedDescription
            pip.update(source: settings.showSourceText ? source : "", translated: "", error: lastError)
            statusLine = lastError ?? ""
            return
        }
        let cacheKey = cache.key(
            engine: settings.translator,
            source: settings.sourceLanguage,
            target: settings.targetLanguage,
            text: source,
            model: settings.openaiModel,
            mode: settings.openaiAPIMode.rawValue
        )
        do {
            let translated: String
            if let hit = cache.get(cacheKey) {
                translated = hit
            } else {
                statusLine = "正在翻译…"
                translated = try await TranslatorFactory.make(settings.translator)
                    .translate(source, settings: settings)
                cache.set(cacheKey, value: translated)
            }
            lastTranslated = translated
            lastError = nil
            lastLatencyMS = Int(Date().timeIntervalSince(ocrStarted) * 1000)
            pip.update(
                source: settings.showSourceText ? source : "",
                translated: translated
            )
            if let lastLatencyMS {
                statusLine = isBroadcasting
                    ? "直播中 · \(lastLatencyMS)ms"
                    : "已更新 · \(lastLatencyMS)ms"
            } else {
                statusLine = isBroadcasting ? "直播中 · 已更新" : "已更新"
            }
        } catch {
            lastError = error.localizedDescription
            pip.update(
                source: settings.showSourceText ? lastSource : "",
                translated: lastTranslated,
                error: lastError
            )
            statusLine = lastError ?? "出错"
        }
    }
}
