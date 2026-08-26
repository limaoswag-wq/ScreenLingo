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
    Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue().stopBroadcastFromApp()
}

/// Thin upload extension: capture frames only. OCR and translation stay in the app.
@objc(SampleHandler)
final class SampleHandler: RPBroadcastSampleHandler {
    private var lastSent: CFTimeInterval = 0
    private var lastSettingsLoad: CFTimeInterval = 0
    private var captureInterval: TimeInterval = AppConstants.captureMinInterval
    private let store = AppGroupStore.shared
    private var stopObserver: UnsafeRawPointer?
    private var lastHostHeartbeat: TimeInterval = Date().timeIntervalSince1970
    private var finishing = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        store.setBroadcasting(true)
        store.touchHostHeartbeat()
        lastHostHeartbeat = Date().timeIntervalSince1970
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
        finishQuietly()
    }

    private func finishQuietly() {
        guard !finishing else { return }
        finishing = true
        store.setBroadcasting(false)
        let graceful = NSSelectorFromString("finishBroadcastGracefully")
        if responds(to: graceful) {
            perform(graceful)
        }
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
        guard sampleBufferType == .video, !finishing else { return }
        let now = CACurrentMediaTime()
        if now - lastSettingsLoad > 1.5 {
            captureInterval = max(store.loadSettings().captureInterval, 0.35)
            lastSettingsLoad = now
        }
        if now - lastHostHeartbeat > 1.2 {
            lastHostHeartbeat = now
            if store.hostHeartbeatAge() > 3 {
                finishQuietly()
                return
            }
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
