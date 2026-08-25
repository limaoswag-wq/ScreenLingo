import AVKit
import SwiftUI
import UIKit
import CoreMedia
import QuartzCore

@MainActor
final class PiPCaptionController: NSObject {
    let hostView = PiPHostUIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var pip: AVPictureInPictureController?
    private var canvasSize = CGSize(width: 720, height: 220)
    private var lastSource = ""
    private var lastTranslated = "屏译已就绪"
    private var lastError: String?

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
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let content = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayLayer,
                playbackDelegate: self
            )
            pip = AVPictureInPictureController(contentSource: content)
            pip?.delegate = self
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        render()
    }

    var isPossible: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func start() {
        render()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.pip?.startPictureInPicture()
        }
    }

    func stop() {
        pip?.stopPictureInPicture()
    }

    func update(source: String, translated: String, error: String? = nil) {
        lastSource = source
        lastTranslated = translated
        lastError = error
        render()
    }

    private func render() {
        guard let buffer = makeBuffer() else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private func makeBuffer() -> CMSampleBuffer? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: canvasSize)
            UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1).setFill()
            ctx.fill(rect)

            let inset = rect.insetBy(dx: 28, dy: 22)
            var y = inset.minY
            let title = NSAttributedString(
                string: "屏译",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor(white: 0.7, alpha: 1)
                ]
            )
            title.draw(at: CGPoint(x: inset.minX, y: y))
            y += 28

            if let lastError, !lastError.isEmpty {
                drawText(lastError, font: .systemFont(ofSize: 22, weight: .medium), color: .systemOrange, in: inset, y: &y)
            } else {
                if !lastSource.isEmpty {
                    drawText(lastSource, font: .systemFont(ofSize: 20, weight: .regular), color: UIColor(white: 0.72, alpha: 1), in: inset, y: &y)
                    y += 8
                }
                drawText(
                    lastTranslated.isEmpty ? "…" : lastTranslated,
                    font: .systemFont(ofSize: 28, weight: .semibold),
                    color: .white,
                    in: inset,
                    y: &y
                )
            }
        }
        return sampleBuffer(from: image)
    }

    private func drawText(_ text: String, font: UIFont, color: UIColor, in inset: CGRect, y: inout CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let remaining = CGRect(x: inset.minX, y: y, width: inset.width, height: max(24, inset.maxY - y))
        let bound = attr.boundingRect(with: remaining.size, options: [.usesLineFragmentOrigin], context: nil)
        attr.draw(with: remaining, options: [.usesLineFragmentOrigin], context: nil)
        y += ceil(bound.height)
    }

    private func sampleBuffer(from image: UIImage) -> CMSampleBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &format)
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

extension PiPCaptionController: AVPictureInPictureControllerDelegate {}

extension PiPCaptionController: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
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
