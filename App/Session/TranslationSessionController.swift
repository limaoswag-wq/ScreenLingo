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

    private let store = AppGroupStore.shared
    private let ocr = OCREngine()
    private let cache = TranslationCache()
    private let pip = PiPCaptionController()
    private var timer: Timer?
    private var lastFrameDate: Date?
    private var lastTextHash = ""
    private var inFlight = false
    private var waitingTicks = 0

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
        waitingTicks = 0
        statusLine = waitingMessage()
        SilentAudio.shared.start()
        pip.update(source: "", translated: "等待屏幕画面…")
        pip.start()
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
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

    private func tick() async {
        isBroadcasting = store.readBroadcasting()
        guard isRunning, !inFlight else { return }
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

    private func waitingMessage() -> String {
        if let error = store.directoryError {
            return error
        }
        if isBroadcasting {
            let channel = store.usingAppGroup ? "App Group" : "共享目录"
            return "直播中，尚未收到画面（\(channel)）"
        }
        return "请点开始直播，并在列表里选「屏译」"
    }

    private func process(image: CGImage, force: Bool) async {
        inFlight = true
        defer { inFlight = false }
        do {
            let boxes = try await ocr.recognize(image: image, settings: settings)
            let source = ocr.joinedText(from: boxes)
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
                text: source
            )
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
            pip.update(
                source: settings.showSourceText ? source : "",
                translated: translated
            )
            statusLine = isBroadcasting ? "直播中 · 已更新" : "已更新"
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
