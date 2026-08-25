import ReplayKit
import CoreMedia
import CoreVideo
import QuartzCore

/// Thin upload extension: capture frames only. OCR and translation stay in the app.
@objc(SampleHandler)
final class SampleHandler: RPBroadcastSampleHandler {
    private var lastSent: CFTimeInterval = 0
    private var lastSettingsLoad: CFTimeInterval = 0
    private var captureInterval: TimeInterval = AppConstants.captureMinInterval
    private let store = AppGroupStore.shared

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        store.setBroadcasting(true)
    }

    override func broadcastPaused() {
        store.setBroadcasting(false)
    }

    override func broadcastResumed() {
        store.setBroadcasting(true)
    }

    override func broadcastFinished() {
        store.setBroadcasting(false)
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
