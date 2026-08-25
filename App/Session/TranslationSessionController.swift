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
    @Published var captionLines: [CaptionLine] = []
    @Published var lastError: String?
    @Published var statusLine = "未开始"
    @Published var lastLatencyMS: Int?
    @Published var availableModels: [String] = []
    @Published var isLoadingModels = false
    @Published var modelListMessage: String?
    @Published var overlayHint = ""
    @Published var isTranslating = false

    private let store = AppGroupStore.shared
    private let ocr = OCREngine()
    private let cache = TranslationCache()
    private let pip = PiPCaptionController()
    private var timer: Timer?
    private var lastFrameDate: Date?
    private var lastTextHash = ""
    private var lastFingerprint: UInt64 = 0
    private var stillCount = 0
    private var jobID: UInt64 = 0
    private var translationTasks: [TranslatorKind: Task<Void, Never>] = [:]
    private var waitingTicks = 0
    private var pasteboardChangeCount = UIPasteboard.general.changeCount
    private var lastPaste = ""
    private var overlayVisible = false
    private var wasBroadcasting = false
    private var broadcastWatcher: Timer?
    private var suppressAutoStart = false

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
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshForegroundHint()
            }
        }
        let watcher = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.watchBroadcast()
            }
        }
        RunLoop.main.add(watcher, forMode: .common)
        broadcastWatcher = watcher
    }

    private func watchBroadcast() {
        let broadcasting = store.readBroadcasting()
        isBroadcasting = broadcasting
        if broadcasting && !isRunning && !suppressAutoStart && settings.translateScene != .reading {
            start()
        }
    }

    func start() {
        suppressAutoStart = false
        isRunning = true
        lastError = nil
        lastLatencyMS = nil
        waitingTicks = 0
        overlayVisible = false
        stillCount = 0
        lastFingerprint = 0
        pasteboardChangeCount = UIPasteboard.general.changeCount
        statusLine = waitingMessage()
        overlayHint = settings.translateScene == .reading
            ? "阅读模式：复制文本就会翻译"
            : "点开始翻译后，在列表里选「屏译」"
        SilentAudio.shared.start()
        pip.fontSize = settings.captionFontSize
        pip.windowSize = settings.captionWindowSize
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        suppressAutoStart = true
        isRunning = false
        timer?.invalidate()
        timer = nil
        cancelTranslations()
        hideOverlay()
        SilentAudio.shared.stop()
        overlayHint = ""
        statusLine = "已停止"
        isTranslating = false
    }

    func previewPhoto(_ image: CGImage) async {
        await process(image: image, force: true)
    }

    func refreshModels() async {
        guard settings.translator == .openai || settings.isEnabled(.openai) else { return }
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
        let broadcasting = store.readBroadcasting()
        isBroadcasting = broadcasting
        pip.fontSize = settings.captionFontSize
        pip.windowSize = settings.captionWindowSize

        if broadcasting && !wasBroadcasting {
            showOverlayIfNeeded()
            refreshForegroundHint()
        } else if !broadcasting && wasBroadcasting {
            hideOverlay()
            overlayHint = "直播已结束"
        }
        wasBroadcasting = broadcasting

        guard isRunning else { return }

        if settings.translateScene == .reading {
            await pollPasteboard()
            return
        }

        guard broadcasting else {
            waitingTicks += 1
            statusLine = waitingMessage()
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
        await applyRecognized(compact, force: true)
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
        return "点开始翻译，在列表里选「屏译」"
    }

    private func process(image: CGImage, force: Bool) async {
        let fingerprint = FrameMotion.fingerprint(image)
        if !force, lastFingerprint != 0 {
            let distance = FrameMotion.distance(lastFingerprint, fingerprint)
            lastFingerprint = fingerprint
            if distance > FrameMotion.motionThreshold {
                stillCount = 0
                cancelTranslations()
                statusLine = "滑动中，等待停稳…"
                return
            }
            stillCount += 1
            if stillCount < 2 { return }
        } else {
            lastFingerprint = fingerprint
            stillCount += 1
        }

        do {
            let boxes = try await ocr.recognize(image: image, settings: settings)
            let source = ocr.joinedText(from: boxes, settings: settings)
            if source.isEmpty {
                statusLine = "这一帧没有识别到字"
                return
            }
            await applyRecognized(source, force: force)
        } catch {
            lastError = error.localizedDescription
            statusLine = lastError ?? "出错"
        }
    }

    private func applyRecognized(_ source: String, force: Bool) async {
        let hash = SHA256.hash(data: Data(source.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        if !force, hash == lastTextHash {
            statusLine = "画面未变，沿用上次译文"
            return
        }
        lastTextHash = hash
        lastSource = source
        lastTranslated = ""
        lastError = nil
        let started = Date()
        jobID += 1
        let currentJob = jobID
        cancelTranslations()
        showRecognized(source)
        let engines = settings.activeTranslators
        if engines.isEmpty {
            captionLines = []
            isTranslating = false
            lastError = "没勾选翻译源"
            pip.update(source: source, lines: [], emptyMessage: "没勾选翻译源")
            statusLine = "没勾选翻译源"
            return
        }
        captionLines = engines.map { kind in
            CaptionLine(
                engine: kind,
                text: "",
                pending: true,
                error: settings.translatorIsConfigured(kind) ? nil : TranslatorError.notConfigured.localizedDescription,
                hex: settings.colorHex(for: kind)
            )
        }
        isTranslating = true
        statusLine = "已识别，正在翻译…"
        refreshOverlay()
        for kind in engines {
            translationTasks[kind] = Task { [weak self] in
                await self?.runEngine(kind, source: source, job: currentJob, started: started)
            }
        }
    }

    private func runEngine(_ kind: TranslatorKind, source: String, job: UInt64, started: Date) async {
        guard settings.translatorIsConfigured(kind) else {
            updateLine(kind, text: "", pending: false, error: TranslatorError.notConfigured.localizedDescription, job: job)
            return
        }
        let cacheKey = cache.key(
            engine: kind,
            source: settings.sourceLanguage,
            target: settings.targetLanguage,
            text: source,
            model: settings.openaiModel,
            mode: settings.openaiAPIMode.rawValue
        )
        if let hit = cache.get(cacheKey) {
            updateLine(kind, text: hit, pending: false, error: nil, job: job)
            finishIfNeeded(job: job, started: started)
            return
        }
        do {
            let translated = try await TranslatorFactory.make(kind).translate(source, settings: settings) { [weak self] partial in
                Task { @MainActor in
                    self?.updateLine(kind, text: partial, pending: true, error: nil, job: job)
                }
            }
            try Task.checkCancellation()
            cache.set(cacheKey, value: translated)
            updateLine(kind, text: translated, pending: false, error: nil, job: job)
            finishIfNeeded(job: job, started: started)
        } catch is CancellationError {
            return
        } catch {
            updateLine(kind, text: "", pending: false, error: error.localizedDescription, job: job)
            finishIfNeeded(job: job, started: started)
        }
    }

    private func updateLine(_ kind: TranslatorKind, text: String, pending: Bool, error: String?, job: UInt64) {
        guard job == jobID else { return }
        if let index = captionLines.firstIndex(where: { $0.engine == kind }) {
            captionLines[index].text = text
            captionLines[index].pending = pending
            captionLines[index].error = error
        }
        if let firstDone = captionLines.first(where: { !$0.pending && !$0.text.isEmpty }) {
            lastTranslated = firstDone.text
        }
        refreshOverlay()
    }

    private func finishIfNeeded(job: UInt64, started: Date) {
        guard job == jobID else { return }
        isTranslating = captionLines.contains(where: \.pending)
        if !isTranslating {
            lastLatencyMS = Int(Date().timeIntervalSince(started) * 1000)
            if let lastLatencyMS {
                statusLine = isBroadcasting ? "直播中 · \(lastLatencyMS)ms" : "已更新 · \(lastLatencyMS)ms"
            }
            refreshForegroundHint()
        }
    }

    private func cancelTranslations() {
        translationTasks.values.forEach { $0.cancel() }
        translationTasks.removeAll()
        isTranslating = false
    }

    private func showRecognized(_ source: String) {
        showOverlayIfNeeded()
        refreshOverlay()
    }

    private func refreshOverlay() {
        pip.update(
            source: settings.showSourceText ? lastSource : "",
            lines: captionLines,
            emptyMessage: settings.activeTranslators.isEmpty ? "没勾选翻译源" : nil
        )
    }

    private func showOverlayIfNeeded() {
        guard isRunning else { return }
        if settings.translateScene == .reading {
            if !overlayVisible {
                overlayVisible = true
                pip.start()
            }
            return
        }
        guard isBroadcasting else { return }
        if !overlayVisible {
            overlayVisible = true
            pip.start()
        }
    }

    private func hideOverlay() {
        overlayVisible = false
        pip.stop()
    }

    private func refreshForegroundHint() {
        guard isRunning, isBroadcasting else { return }
        if UIApplication.shared.applicationState == .active {
            overlayHint = "切换到其他 App 开始翻译"
        } else {
            overlayHint = ""
        }
    }
}

enum FrameMotion {
    /// Hamming distance on an 8x8 average hash. Around 10+ means the shot moved a lot.
    static let motionThreshold: UInt64 = 10

    static func fingerprint(_ image: CGImage) -> UInt64 {
        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var luma = [UInt64](repeating: 0, count: width * height)
        var total: UInt64 = 0
        for i in 0..<(width * height) {
            let value = (UInt64(pixels[i * 4]) * 3 + UInt64(pixels[i * 4 + 1]) * 6 + UInt64(pixels[i * 4 + 2])) / 10
            luma[i] = value
            total += value
        }
        let mean = total / UInt64(width * height)
        var hash: UInt64 = 0
        for i in 0..<(width * height) {
            if luma[i] >= mean {
                hash |= 1 << i
            }
        }
        return hash
    }

    static func distance(_ a: UInt64, _ b: UInt64) -> UInt64 {
        UInt64((a ^ b).nonzeroBitCount)
    }
}
