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
    var fontSize: CaptionFontSize = .small
    var windowSize: CaptionWindowSize = .compact
    var background: OverlayBackground = .dim
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

    func update(source: String, lines: [CaptionLine], emptyMessage: String? = nil) {
        lastSource = source
        lastLines = lines
        self.emptyMessage = emptyMessage
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
        let canvas = fittedCanvas()
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            drawOverlay(in: ctx.cgContext, size: canvas)
        }
        return sampleBuffer(from: image)
    }

    private func fittedCanvas() -> CGSize {
        let width = windowSize.width
        let pad: CGFloat = 16
        let inner = width - pad * 2
        var height = pad
        if !lastSource.isEmpty {
            height += 22 + textHeight(lastSource, font: sourceFont, width: inner - 8) + 12
        }
        if let emptyMessage, lastLines.isEmpty {
            height += 22 + textHeight(emptyMessage, font: sourceFont, width: inner - 8) + 8
        } else if lastLines.isEmpty && lastSource.isEmpty {
            height += 36
        } else {
            for line in lastLines {
                height += 22 + textHeight(line.displayText, font: translatedFont, width: inner - 8) + 10
            }
        }
        height += pad
        return CGSize(width: width, height: min(max(height, 108), 420))
    }

    private var sourceFont: UIFont { UIFont.systemFont(ofSize: fontSize.sourcePoints, weight: .regular) }
    private var translatedFont: UIFont { UIFont.systemFont(ofSize: fontSize.translatedPoints, weight: .semibold) }
    private var chipFont: UIFont { UIFont.systemFont(ofSize: 11, weight: .semibold) }

    private func drawOverlay(in ctx: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        fillColor.setFill()
        ctx.fill(rect)

        let card = rect.insetBy(dx: 8, dy: 8)
        let cardPath = UIBezierPath(roundedRect: card, cornerRadius: 18)
        cardFill.setFill()
        cardPath.fill()
        UIColor.white.withAlphaComponent(0.10).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()

        let inset = card.insetBy(dx: 14, dy: 12)
        var y = inset.minY
        if !lastSource.isEmpty {
            y = drawBlock(
                title: "原文",
                text: lastSource,
                accent: UIColor.white.withAlphaComponent(0.85),
                textColor: UIColor.white.withAlphaComponent(0.88),
                font: sourceFont,
                in: inset,
                y: y
            )
        }
        if let emptyMessage, lastLines.isEmpty {
            y = drawBlock(
                title: "提示",
                text: emptyMessage,
                accent: .systemOrange,
                textColor: .systemOrange,
                font: sourceFont,
                in: inset,
                y: y
            )
        } else if lastLines.isEmpty && lastSource.isEmpty {
            drawText(
                "切换到其他 App 开始翻译",
                font: sourceFont,
                color: UIColor.white.withAlphaComponent(0.72),
                in: CGRect(x: inset.minX, y: y, width: inset.width, height: 28)
            )
        } else {
            for line in lastLines {
                let accent = HexColor.uiColor(from: line.hex)
                let color: UIColor = {
                    if line.error != nil { return .systemOrange }
                    if line.pending && line.text.isEmpty { return UIColor.white.withAlphaComponent(0.55) }
                    return accent
                }()
                y = drawBlock(
                    title: line.engine.shortTitle,
                    text: line.displayText,
                    accent: accent,
                    textColor: color,
                    font: translatedFont,
                    in: inset,
                    y: y
                )
                if y > inset.maxY { break }
            }
        }
    }

    private func drawBlock(
        title: String,
        text: String,
        accent: UIColor,
        textColor: UIColor,
        font: UIFont,
        in inset: CGRect,
        y: CGFloat
    ) -> CGFloat {
        let textHeight = textHeight(text, font: font, width: inset.width - 8)
        let blockHeight = 22 + textHeight + 8
        let block = CGRect(x: inset.minX, y: y, width: inset.width, height: blockHeight)
        let path = UIBezierPath(roundedRect: block, cornerRadius: 12)
        UIColor.white.withAlphaComponent(0.06).setFill()
        path.fill()

        let bar = UIBezierPath(roundedRect: CGRect(x: block.minX, y: block.minY + 8, width: 4, height: block.height - 16), cornerRadius: 2)
        accent.setFill()
        bar.fill()

        drawChip(title, accent: accent, at: CGPoint(x: block.minX + 14, y: block.minY + 6))
        drawText(
            text,
            font: font,
            color: textColor,
            in: CGRect(x: block.minX + 14, y: block.minY + 22, width: block.width - 22, height: textHeight)
        )
        return y + blockHeight + 8
    }

    private func drawChip(_ title: String, accent: UIColor, at origin: CGPoint) {
        let attr = NSAttributedString(string: title, attributes: [
            .font: chipFont,
            .foregroundColor: UIColor.white
        ])
        let size = attr.size()
        let chip = CGRect(x: origin.x, y: origin.y, width: size.width + 12, height: 16)
        let path = UIBezierPath(roundedRect: chip, cornerRadius: 8)
        accent.withAlphaComponent(0.85).setFill()
        path.fill()
        attr.draw(in: CGRect(x: chip.minX + 6, y: chip.minY + 1, width: size.width, height: size.height))
    }

    private func drawText(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attr.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
    }

    private func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])
        let bound = attr.boundingRect(with: CGSize(width: width, height: 280), options: [.usesLineFragmentOrigin], context: nil)
        return max(18, ceil(bound.height))
    }

    private var fillColor: UIColor {
        switch background {
        case .solid: return UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        case .dim: return UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
        case .ink: return UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
        }
    }

    private var cardFill: UIColor {
        switch background {
        case .solid: return UIColor(white: 0.14, alpha: 1)
        case .dim: return UIColor(white: 0.16, alpha: 1)
        case .ink: return UIColor(white: 0.11, alpha: 1)
        }
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
