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
    var fontSize: CaptionFontSize = .medium
    var windowSize: CaptionWindowSize = .medium {
        didSet { canvasSize = windowSize.canvas }
    }
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

            let inset = rect.insetBy(dx: 28, dy: 18)
            if let lastError, !lastError.isEmpty {
                drawCentered(
                    lastError,
                    font: .systemFont(ofSize: fontSize.sourcePoints, weight: .medium),
                    color: .systemOrange,
                    in: inset
                )
            } else {
                let source = lastSource
                let translated = lastTranslated
                if source.isEmpty && translated.isEmpty {
                    drawCentered("切换到其他 App 开始翻译", font: .systemFont(ofSize: fontSize.sourcePoints, weight: .medium), color: UIColor(white: 0.78, alpha: 1), in: inset)
                } else if source.isEmpty {
                    drawCentered(translated, font: .systemFont(ofSize: fontSize.translatedPoints, weight: .semibold), color: UIColor(red: 0.55, green: 0.92, blue: 0.95, alpha: 1), in: inset)
                } else {
                    let gap: CGFloat = 10
                    let sourceFont = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .regular)
                    let transFont = UIFont.systemFont(ofSize: fontSize.translatedPoints, weight: .semibold)
                    let sourceHeight = height(of: source, font: sourceFont, width: inset.width)
                    let transHeight = height(of: translated.isEmpty ? "翻译中…" : translated, font: transFont, width: inset.width)
                    let total = sourceHeight + gap + transHeight
                    var y = inset.midY - total / 2
                    drawCentered(source, font: sourceFont, color: .white, in: CGRect(x: inset.minX, y: y, width: inset.width, height: sourceHeight))
                    y += sourceHeight + gap
                    let lineY = y - gap / 2
                    UIColor(white: 1, alpha: 0.18).setStroke()
                    let line = UIBezierPath()
                    line.move(to: CGPoint(x: inset.minX + 24, y: lineY))
                    line.addLine(to: CGPoint(x: inset.maxX - 24, y: lineY))
                    line.lineWidth = 1
                    line.stroke()
                    drawCentered(
                        translated.isEmpty ? "翻译中…" : translated,
                        font: transFont,
                        color: translated.isEmpty ? UIColor(white: 0.72, alpha: 1) : UIColor(red: 0.55, green: 0.92, blue: 0.95, alpha: 1),
                        in: CGRect(x: inset.minX, y: y, width: inset.width, height: transHeight)
                    )
                }
            }
        }
        return sampleBuffer(from: image)
    }

    private func drawCentered(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let bound = attr.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], context: nil)
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - ceil(bound.height)) / 2),
            width: rect.width,
            height: min(rect.height, ceil(bound.height))
        )
        attr.draw(with: drawRect, options: [.usesLineFragmentOrigin], context: nil)
    }

    private func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])
        let bound = attr.boundingRect(with: CGSize(width: width, height: 400), options: [.usesLineFragmentOrigin], context: nil)
        return max(24, ceil(bound.height))
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
