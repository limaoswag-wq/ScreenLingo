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
        request.usesLanguageCorrection = false
        request.minimumTextHeight = settings.ocrEngine == .visionFast ? 0.028 : 0.018
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
            let mapped = mapBox(observation.boundingBox, cropRect: cropRect, fullSize: fullSize)
            return TextBox(text: text, boundingBox: mapped)
        }
        .sorted { lhs, rhs in
            if abs(lhs.boundingBox.origin.y - rhs.boundingBox.origin.y) > 0.02 {
                return lhs.boundingBox.origin.y > rhs.boundingBox.origin.y
            }
            return lhs.boundingBox.origin.x < rhs.boundingBox.origin.x
        }
    }

    func joinedText(from boxes: [TextBox], settings: AppSettings) -> String {
        let limited = Array(boxes.prefix(settings.translateScene == .manga ? 8 : 12))
        let joined = limited.map(\.text).joined(separator: "\n")
        return compactForTranslation(joined)
    }

    func compactForTranslation(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        var seen = Set<String>()
        for line in lines {
            if seen.insert(line).inserted {
                unique.append(line)
            }
        }
        let joined = unique.joined(separator: "\n")
        if joined.count <= 420 { return joined }
        return String(joined.prefix(420))
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
            return smartBand(in: size, scene: settings.translateScene)
        }
    }

    private func smartBand(in size: CGSize, scene: TranslateScene) -> CGRect {
        let landscape = size.width > size.height
        switch scene {
        case .video:
            if landscape {
                return OCRRegion(x: 0.08, y: 0.74, width: 0.84, height: 0.20).pixelRect(in: size)
            }
            return OCRRegion(x: 0.06, y: 0.08, width: 0.88, height: 0.18).pixelRect(in: size)
        case .game:
            if landscape {
                return OCRRegion(x: 0.10, y: 0.62, width: 0.80, height: 0.30).pixelRect(in: size)
            }
            return OCRRegion(x: 0.06, y: 0.58, width: 0.88, height: 0.32).pixelRect(in: size)
        case .manga:
            return OCRRegion(x: 0.18, y: 0.28, width: 0.64, height: 0.44).pixelRect(in: size)
        case .reading:
            return OCRRegion(x: 0.08, y: 0.18, width: 0.84, height: 0.64).pixelRect(in: size)
        }
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
