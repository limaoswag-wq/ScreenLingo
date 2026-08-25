import Foundation
import CoreGraphics

enum AppConstants {
    static let appBundleID = "dev.screenlingo.app"
    static let broadcastBundleID = "dev.screenlingo.app.broadcast"
    static let appGroupID = "group.dev.screenlingo"
    static let darwinFrameReady = "dev.screenlingo.frameReady"
    static let darwinBroadcastState = "dev.screenlingo.broadcastState"

    static let frameFileName = "latest.jpg"
    static let frameMetaFileName = "latest.json"
    static let broadcastStateFileName = "broadcast.json"

    /// Broadcast extension send interval. OCR is more expensive than capture.
    static let captureMinInterval: TimeInterval = 0.55
    static let jpegQuality: CGFloat = 0.55
    static let maxFrameWidth: CGFloat = 1280
}
