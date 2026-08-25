import Foundation
import Vision
import CoreGraphics

struct OCREngine {
    func recognize(
        image: CGImage,
        settings: AppSettings
    ) async throws -> [TextBox] {
        let cropped = crop(image, settings: settings)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = settings.ocrEngine == .visionFast ? .fast : .accurate
        request.usesLanguageCorrection = settings.ocrEngine == .visionAccurate
        request.minimumTextHeight = settings.ocrEngine == .visionFast ? 0.03 : 0.015
        request.recognitionLanguages = preferredLanguages(source: settings.sourceLanguage)

        let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []

        let cropRect = cropRect(in: CGSize(width: image.width, height: image.height), settings: settings)
        let fullSize = CGSize(width: image.width, height: image.height)

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 1 else { return nil }
            let boxInCrop = observation.boundingBox
            let mapped = mapBox(boxInCrop, cropRect: cropRect, fullSize: fullSize)
            return TextBox(text: text, boundingBox: mapped)
        }
        .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
    }

    func joinedText(from boxes: [TextBox]) -> String {
        boxes.map(\.text).joined(separator: "\n")
    }

    private func preferredLanguages(source: String) -> [String] {
        switch source {
        case "ja": return ["ja-JP", "en-US"]
        case "ko": return ["ko-KR", "en-US"]
        case "zh-Hans": return ["zh-Hans", "en-US"]
        case "zh-Hant": return ["zh-Hant", "en-US"]
        case "en": return ["en-US"]
        case "fr": return ["fr-FR", "en-US"]
        case "de": return ["de-DE", "en-US"]
        case "es": return ["es-ES", "en-US"]
        case "ru": return ["ru-RU", "en-US"]
        case "vi": return ["vi-VN", "en-US"]
        case "th": return ["th-TH", "en-US"]
        default:
            return ["ja-JP", "en-US", "zh-Hans", "ko-KR"]
        }
    }

    private func crop(_ image: CGImage, settings: AppSettings) -> CGImage {
        let size = CGSize(width: image.width, height: image.height)
        let rect = cropRect(in: size, settings: settings).integral
        return image.cropping(to: rect) ?? image
    }

    private func cropRect(in size: CGSize, settings: AppSettings) -> CGRect {
        switch settings.recognitionMode {
        case .full:
            return CGRect(origin: .zero, size: size)
        case .custom:
            return settings.customRegion.pixelRect(in: size)
        case .smart:
            return smartBand(in: size)
        }
    }

    /// Horizontal subtitle/dialogue band: lower third on landscape-ish frames, otherwise a mid-lower strip.
    private func smartBand(in size: CGSize) -> CGRect {
        let landscape = size.width > size.height
        if landscape {
            return OCRRegion(x: 0.08, y: 0.72, width: 0.84, height: 0.22).pixelRect(in: size)
        }
        return OCRRegion(x: 0.06, y: 0.62, width: 0.88, height: 0.28).pixelRect(in: size)
    }

    /// Vision boxes are bottom-left. `cropRect` is top-left in image pixels.
    private func mapBox(_ box: CGRect, cropRect: CGRect, fullSize: CGSize) -> CGRect {
        let x = (cropRect.origin.x + box.origin.x * cropRect.width) / fullSize.width
        let yFromBottom = (fullSize.height - cropRect.maxY) + box.origin.y * cropRect.height
        let y = yFromBottom / fullSize.height
        let w = (box.width * cropRect.width) / fullSize.width
        let h = (box.height * cropRect.height) / fullSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
