import Foundation
import CoreImage
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

final class AppGroupStore {
    static let shared = AppGroupStore()

    let defaults: UserDefaults
    let containerURL: URL?
    let usingAppGroup: Bool
    let directoryError: String?

    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: true,
        .cacheIntermediates: false
    ])
    private let encoderQueue = DispatchQueue(label: "dev.screenlingo.frame-encoder")

    private init() {
        let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )
        if let groupURL {
            try? FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)
            defaults = groupDefaults ?? .standard
            containerURL = groupURL
            usingAppGroup = true
            directoryError = nil
        } else if let fallback = Self.makeFallbackDirectory() {
            defaults = .standard
            containerURL = fallback
            usingAppGroup = false
            directoryError = nil
        } else {
            defaults = .standard
            containerURL = nil
            usingAppGroup = false
            directoryError = "共享目录不可用。扩展写不出画面，主程序也读不到。"
        }
    }

    var debugPath: String {
        containerURL?.path ?? "(无)"
    }

    func loadSettings() -> AppSettings {
        if let data = defaults.data(forKey: AppSettings.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded
        }
        if let dir = containerURL,
           let data = try? Data(contentsOf: dir.appendingPathComponent("settings.json")),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded
        }
        return AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: AppSettings.storageKey)
            if let dir = containerURL {
                atomicWrite(data, to: dir.appendingPathComponent("settings.json"))
            }
        }
    }

    func setBroadcasting(_ running: Bool) {
        let state = BroadcastState(
            isBroadcasting: running,
            startedAt: running ? Date().timeIntervalSince1970 : nil
        )
        writeJSON(state, name: AppConstants.broadcastStateFileName)
        writeDebug("broadcasting=\(running)")
        postDarwin(name: AppConstants.darwinBroadcastState)
    }

    func readBroadcasting() -> Bool {
        readJSON(BroadcastState.self, name: AppConstants.broadcastStateFileName)?.isBroadcasting ?? false
    }

    func writePixelBuffer(_ pixelBuffer: CVPixelBuffer, orientation: Int) {
        encoderQueue.async { [weak self] in
            self?.encodeAndWrite(pixelBuffer: pixelBuffer, orientation: orientation)
        }
    }

    func readFrameImage() -> (CGImage, FrameMeta)? {
        guard let dir = containerURL else { return nil }
        let url = dir.appendingPathComponent(AppConstants.frameFileName)
        guard
            let data = try? Data(contentsOf: url),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let meta = readJSON(FrameMeta.self, name: AppConstants.frameMetaFileName)
            ?? FrameMeta(
                width: image.width,
                height: image.height,
                timestamp: Date().timeIntervalSince1970,
                orientation: 1
            )
        return (image, meta)
    }

    func frameModificationDate() -> Date? {
        guard let dir = containerURL else { return nil }
        let url = dir.appendingPathComponent(AppConstants.frameFileName)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func encodeAndWrite(pixelBuffer: CVPixelBuffer, orientation: Int) {
        guard let dir = containerURL else {
            return
        }
        guard let data = jpegData(from: pixelBuffer) else {
            writeDebug("jpeg encode failed")
            return
        }
        let frameURL = dir.appendingPathComponent(AppConstants.frameFileName)
        atomicWrite(data, to: frameURL)

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let meta = FrameMeta(
            width: width,
            height: height,
            timestamp: Date().timeIntervalSince1970,
            orientation: orientation
        )
        writeJSON(meta, name: AppConstants.frameMetaFileName)
        writeDebug("frame \(width)x\(height) bytes=\(data.count)")
        postDarwin(name: AppConstants.darwinFrameReady)
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let scale = min(1, AppConstants.maxFrameWidth / max(extent.width, 1))
        let scaled = scale < 0.999
            ? ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : ciImage
        let rect = scaled.extent.integral
        guard let cgImage = ciContext.createCGImage(scaled, from: rect) else { return nil }
        return jpegData(from: cgImage)
    }

    private func jpegData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: AppConstants.jpegQuality
        ]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func writeJSON<T: Encodable>(_ value: T, name: String) {
        guard let dir = containerURL, let data = try? JSONEncoder().encode(value) else { return }
        atomicWrite(data, to: dir.appendingPathComponent(name))
    }

    private func readJSON<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let dir = containerURL else { return nil }
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func writeDebug(_ line: String) {
        guard let dir = containerURL else { return }
        let text = "\(Date().timeIntervalSince1970) \(line)\n"
        let url = dir.appendingPathComponent("debug.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        } else {
            try? Data(text.utf8).write(to: url)
        }
    }

    private func atomicWrite(_ data: Data, to url: URL) {
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
        } catch {
            try? data.write(to: url, options: .atomic)
        }
    }

    func postDarwin(name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    /// Jailbreak / TrollStore fallback when App Group container is missing.
    private static func makeFallbackDirectory() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/var/tmp/dev.screenlingo", isDirectory: true),
            URL(fileURLWithPath: "/tmp/dev.screenlingo", isDirectory: true),
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("dev.screenlingo", isDirectory: true)
        ].compactMap { $0 }
        for url in candidates {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                let probe = url.appendingPathComponent(".probe")
                try Data("ok".utf8).write(to: probe)
                try FileManager.default.removeItem(at: probe)
                return url
            } catch {
                continue
            }
        }
        return nil
    }
}
