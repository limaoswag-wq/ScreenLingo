import Foundation
import CoreImage
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

final class AppGroupStore {
    static let shared = AppGroupStore()

    let defaults: UserDefaults
    let containerURL: URL?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let encoderQueue = DispatchQueue(label: "dev.screenlingo.frame-encoder")

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: AppSettings.storageKey) else {
            return AppSettings()
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: AppSettings.storageKey)
        }
    }

    func setBroadcasting(_ running: Bool) {
        let state = BroadcastState(
            isBroadcasting: running,
            startedAt: running ? Date().timeIntervalSince1970 : nil
        )
        writeJSON(state, name: AppConstants.broadcastStateFileName)
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
        guard
            let dir = containerURL,
            let data = try? Data(contentsOf: dir.appendingPathComponent(AppConstants.frameFileName)),
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
        guard let dir = containerURL else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let scale = min(1, AppConstants.maxFrameWidth / max(extent.width, 1))
        let scaled: CIImage
        if scale < 0.999 {
            scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        } else {
            scaled = ciImage
        }
        let rect = scaled.extent.integral
        guard let cgImage = ciContext.createCGImage(scaled, from: rect) else { return }
        guard let data = jpegData(from: cgImage) else { return }

        let frameURL = dir.appendingPathComponent(AppConstants.frameFileName)
        atomicWrite(data, to: frameURL)

        let meta = FrameMeta(
            width: cgImage.width,
            height: cgImage.height,
            timestamp: Date().timeIntervalSince1970,
            orientation: orientation
        )
        writeJSON(meta, name: AppConstants.frameMetaFileName)
        postDarwin(name: AppConstants.darwinFrameReady)
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

    private func atomicWrite(_ data: Data, to url: URL) {
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
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
}
