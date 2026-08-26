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
        didSet {
            guard oldValue != windowSize else { return }
            canvasSize = windowSize.canvas
            render()
        }
    }
    private var canvasSize = CGSize(width: 390, height: 96)
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
        canvasSize = windowSize.canvas
        setupPiP()
        render()
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
        let image = makeImage()
        guard let buffer = sampleBuffer(from: image) else { return }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private func makeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 2
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: canvasSize)
            UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1).setFill()
            ctx.fill(rect)

            let inset = rect.insetBy(dx: 16, dy: 8)
            var y = inset.minY
            if !lastSource.isEmpty {
                let sourceFont = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .regular)
                let sourceHeight = min(inset.height * 0.38, height(of: lastSource, font: sourceFont, width: inset.width))
                drawText(lastSource, font: sourceFont, color: .white, in: CGRect(x: inset.minX, y: y, width: inset.width, height: sourceHeight))
                y += sourceHeight + 6
                UIColor(white: 1, alpha: 0.18).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: inset.minX + 24, y: y))
                line.addLine(to: CGPoint(x: inset.maxX - 24, y: y))
                line.lineWidth = 1
                line.stroke()
                y += 6
            }
            if let emptyMessage, lastLines.isEmpty {
                let font = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .medium)
                let h = height(of: emptyMessage, font: font, width: inset.width)
                drawText(emptyMessage, font: font, color: .systemOrange, in: CGRect(x: inset.minX, y: y, width: inset.width, height: h))
            } else if lastLines.isEmpty && lastSource.isEmpty {
                let text = "切换到其他 App 开始翻译"
                let font = UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .medium)
                let h = height(of: text, font: font, width: inset.width)
                drawText(text, font: font, color: UIColor(white: 0.78, alpha: 1), in: CGRect(x: inset.minX, y: y, width: inset.width, height: h))
            } else {
                let transFont = UIFont.systemFont(ofSize: fontSize.translatedPoints, weight: .semibold)
                for line in lastLines.prefix(3) {
                    let text = line.displayText
                    let color: UIColor = {
                        if line.error != nil { return .systemOrange }
                        if line.pending && line.text.isEmpty { return UIColor(white: 0.72, alpha: 1) }
                        return HexColor.uiColor(from: line.hex)
                    }()
                    let remain = inset.maxY - y
                    guard remain > 16 else { break }
                    let h = min(remain, height(of: text, font: transFont, width: inset.width))
                    drawText(text, font: transFont, color: color, in: CGRect(x: inset.minX, y: y, width: inset.width, height: h))
                    y += h + 3
                }
            }
        }
    }

    private func drawText(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attr.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])
        let bound = attr.boundingRect(with: CGSize(width: width, height: 120), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return max(18, ceil(bound.height))
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

extension PiPCaptionController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        hideTransportChrome()
        render()
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
