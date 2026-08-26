import ReplayKit
import CoreMedia
import CoreVideo
import QuartzCore

private func screenLingoStopBroadcast(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
    handler.stopBroadcastFromApp()
}

/// Thin upload extension: capture frames only. OCR and translation stay in the app.
@objc(SampleHandler)
final class SampleHandler: RPBroadcastSampleHandler {
    private var lastSent: CFTimeInterval = 0
    private var lastSettingsLoad: CFTimeInterval = 0
    private var captureInterval: TimeInterval = AppConstants.captureMinInterval
    private let store = AppGroupStore.shared
    private var stopObserver: UnsafeRawPointer?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        store.setBroadcasting(true)
        listenForStop()
    }

    override func broadcastPaused() {
        store.setBroadcasting(false)
    }

    override func broadcastResumed() {
        store.setBroadcasting(true)
        listenForStop()
    }

    override func broadcastFinished() {
        store.setBroadcasting(false)
        unlistenForStop()
    }

    private func listenForStop() {
        unlistenForStop()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        stopObserver = UnsafeRawPointer(observer)
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            UnsafeMutableRawPointer(observer),
            screenLingoStopBroadcast,
            AppConstants.darwinStopBroadcast as CFString,
            nil,
            .deliverImmediately
        )
    }

    @objc fileprivate func stopBroadcastFromApp() {
        let selector = NSSelectorFromString("finishBroadcastWithError:")
        if responds(to: selector) {
            let error = NSError(
                domain: "dev.screenlingo.broadcast",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "stopped from app"]
            )
            perform(selector, with: error)
            return
        }
        finishBroadcastWithError(
            NSError(
                domain: "dev.screenlingo.broadcast",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "stopped from app"]
            )
        )
    }

    private func unlistenForStop() {
        guard let stopObserver else { return }
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            UnsafeMutableRawPointer(mutating: stopObserver),
            CFNotificationName(AppConstants.darwinStopBroadcast as CFString),
            nil
        )
        self.stopObserver = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = CACurrentMediaTime()
        if now - lastSettingsLoad > 1.5 {
            captureInterval = max(store.loadSettings().captureInterval, 0.35)
            lastSettingsLoad = now
        }
        guard now - lastSent >= captureInterval else { return }
        lastSent = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var orientation = 1
        if let attachment = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber {
            orientation = attachment.intValue
        }
        store.writePixelBuffer(pixelBuffer, orientation: orientation)
    }
}
