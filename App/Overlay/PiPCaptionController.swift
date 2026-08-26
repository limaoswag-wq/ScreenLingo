import AVKit
import SwiftUI
import UIKit
import CoreMedia
import QuartzCore

@MainActor
final class PiPCaptionController: NSObject {
    let hostView = PiPHostUIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
    private let displayLayer = AVSampleBufferDisplayLayer()
    private let board = CaptionBoardView(frame: .zero)
    private var pip: AVPictureInPictureController?
    var fontSize: CaptionFontSize = .medium
    var windowSize: CaptionWindowSize = .medium {
        didSet {
            guard oldValue != windowSize else { return }
            canvasSize = windowSize.canvas
            layoutBoard()
            render()
        }
    }
    private var canvasSize = CGSize(width: 360, height: 140)
    private var lastSource = ""
    private var lastLines: [CaptionLine] = []
    private var emptyMessage: String?

    override init() {
        super.init()
        hostView.backgroundColor = .black
        hostView.isUserInteractionEnabled = false
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        hostView.layer.addSublayer(displayLayer)
        displayLayer.frame = hostView.bounds
        hostView.onLayout = { [weak self] bounds in
            self?.displayLayer.frame = bounds
        }
        board.isHidden = true
        canvasSize = windowSize.canvas
        layoutBoard()
        setupPiP()
        render()
    }

    private func layoutBoard() {
        board.bounds = CGRect(origin: .zero, size: canvasSize)
        board.frame = CGRect(origin: .zero, size: canvasSize)
    }

    private func setupPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        pip = AVPictureInPictureController(contentSource: source)
        pip?.delegate = self
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
        hideTransportChrome()
    }

    private func hideTransportChrome() {
        guard let pip else { return }
        if #available(iOS 16.0, *) {
            pip.requiresLinearPlayback = true
        }
        if pip.responds(to: NSSelectorFromString("setControlsStyle:")) {
            pip.setValue(1, forKey: "controlsStyle")
        }
        if pip.responds(to: NSSelectorFromString("setRequiresLinearPlayback:")) {
            pip.setValue(true, forKey: "requiresLinearPlayback")
        }
    }

    var isPossible: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func start() {
        canvasSize = windowSize.canvas
        layoutBoard()
        if pip == nil {
            setupPiP()
        }
        render()
        hideTransportChrome()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.hideTransportChrome()
            if self.pip?.isPictureInPictureActive != true {
                self.pip?.startPictureInPicture()
            }
        }
    }

    func stop() {
        pip?.stopPictureInPicture()
    }

    func rebuild() {
        pip?.stopPictureInPicture()
        pip = nil
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        setupPiP()
        render()
    }

    func update(source: String, lines: [CaptionLine], emptyMessage: String? = nil) {
        lastSource = source
        lastLines = lines
        self.emptyMessage = emptyMessage
        render()
    }

    private func render() {
        board.apply(
            source: lastSource,
            lines: lastLines,
            emptyMessage: emptyMessage,
            fontSize: fontSize
        )
        layoutBoard()
        board.layoutIfNeeded()
        guard let buffer = sampleBuffer(from: board) else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private func sampleBuffer(from view: UIView) -> CMSampleBuffer? {
        let scale: CGFloat = 2
        let width = max(2, Int(view.bounds.width * scale))
        let height = max(2, Int(view.bounds.height * scale))
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        view.layer.render(in: context)

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &format
        )
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: CMTimeValue(CACurrentMediaTime() * 1000), timescale: 1000),
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        return sample
    }
}

final class PiPHostUIView: UIView {
    var onLayout: ((CGRect) -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds)
    }
}

struct PiPHostRepresentable: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension PiPCaptionController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        hideTransportChrome()
    }
}

extension PiPCaptionController: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(seconds: 3600, preferredTimescale: 1))
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool { false }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
