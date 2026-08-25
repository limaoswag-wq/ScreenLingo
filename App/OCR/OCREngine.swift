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
    }

    func joinedText(from boxes: [TextBox], settings: AppSettings) -> String {
        let lines = groupIntoLines(boxes)
        guard !lines.isEmpty else { return "" }
        let joiner = prefersSpaces(in: boxes, source: settings.sourceLanguage) ? " " : ""
        let lineTexts = lines.map { line in
            line.map(\.text).joined(separator: joiner)
        }
        let merged: String
        switch settings.translateScene {
        case .manga:
            merged = lineTexts.joined(separator: joiner)
        case .game:
            merged = lineTexts.joined(separator: "\n")
        case .video, .reading:
            merged = mergeCloseLines(lineTexts, boxesByLine: lines, joiner: joiner)
        }
        return compactForTranslation(merged)
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

    /// Vision returns one box per visual line. Manga bubbles should read as one sentence.
    private func groupIntoLines(_ boxes: [TextBox]) -> [[TextBox]] {
        let sorted = boxes.sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.016 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        var lines: [[TextBox]] = []
        for box in sorted {
            if let ref = lines.last?.first {
                let threshold = max(0.02, ref.boundingBox.height * 0.7)
                if abs(box.boundingBox.midY - ref.boundingBox.midY) < threshold {
                    lines[lines.count - 1].append(box)
                    lines[lines.count - 1].sort { $0.boundingBox.minX < $1.boundingBox.minX }
                    continue
                }
            }
            lines.append([box])
        }
        return lines
    }

    private func mergeCloseLines(_ texts: [String], boxesByLine: [[TextBox]], joiner: String) -> String {
        guard texts.count == boxesByLine.count, !texts.isEmpty else {
            return texts.joined(separator: "\n")
        }
        var out: [String] = [texts[0]]
        for index in 1..<texts.count {
            let previous = boxesByLine[index - 1][0]
            let current = boxesByLine[index][0]
            let gap = previous.boundingBox.minY - current.boundingBox.maxY
            let close = gap < max(0.035, previous.boundingBox.height * 1.15)
            let overlapX = min(previous.boundingBox.maxX, current.boundingBox.maxX) - max(previous.boundingBox.minX, current.boundingBox.minX)
            let similarWidth = overlapX > min(previous.boundingBox.width, current.boundingBox.width) * 0.35
            if close && similarWidth {
                out[out.count - 1] = [out[out.count - 1], texts[index]].joined(separator: joiner)
            } else {
                out.append(texts[index])
            }
        }
        return out.joined(separator: "\n")
    }

    private func prefersSpaces(in boxes: [TextBox], source: String) -> Bool {
        switch source {
        case "ja", "zh-Hans", "zh-Hant":
            return false
        case "en", "ko", "fr", "de", "es", "ru", "vi", "th":
            return true
        default:
            let text = boxes.map(\.text).joined()
            let cjk = text.unicodeScalars.filter { scalar in
                (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
            }.count
            return Double(cjk) / Double(max(text.count, 1)) < 0.35
        }
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
            return ["ko-KR", "ja-JP", "en-US", "zh-Hans"]
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
            return OCRRegion(x: 0.12, y: 0.18, width: 0.76, height: 0.58).pixelRect(in: size)
        case .reading:
            return OCRRegion(x: 0.08, y: 0.18, width: 0.84, height: 0.64).pixelRect(in: size)
        }
    }

    private func mapBox(_ box: CGRect, cropRect: CGRect, fullSize: CGSize) -> CGRect {
        let x = (cropRect.origin.x + box.origin.x * cropRect.width) / fullSize.width
        let yFromBottom = (fullSize.height - cropRect.maxY) + box.origin.y * cropRect.height
        let y = yFromBottom / fullSize.height
        let w = (box.width * cropRect.width) / fullSize.width
        let h = (box.height * cropRect.height) / fullSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
