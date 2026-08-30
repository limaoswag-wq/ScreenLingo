import Foundation
import Vision
import CoreGraphics

struct OCREngine {
    func recognize(
        image: CGImage,
        settings: AppSettings
    ) async throws -> [TextBox] {
        let cropped = crop(image, settings: settings)
        let cropRect = cropRect(in: CGSize(width: image.width, height: image.height), settings: settings)
        let fullSize = CGSize(width: image.width, height: image.height)
        let languages = ocrLanguages(settings: settings)
        let useMLKit = settings.ocrEngine == .mlkit && (settings.sourceLanguage == "ja" || settings.sourceLanguage == "ko")
        if useMLKit, let mlkit = MLKitOCR.recognize(
            image: cropped,
            sourceLanguage: settings.sourceLanguage,
            cropRect: cropRect,
            fullSize: fullSize
        ), !mlkit.isEmpty {
            return mlkit.filter { $0.confidence >= 0.20 }
        }

        let accurate = settings.translateScene == .manga || settings.ocrEngine == .visionAccurate || useMLKit
        let minHeight: Float = settings.translateScene == .manga ? 0.010 : (accurate ? 0.018 : 0.028)

        let boxes = try recognizePass(
            cropped,
            languages: languages,
            accurate: accurate,
            minHeight: minHeight,
            cropRect: cropRect,
            fullSize: fullSize
        )
        let minConfidence: Float = settings.translateScene == .manga ? 0.30 : 0.12
        return boxes.filter { $0.confidence >= minConfidence }
    }

    func looksLikeHomeScreen(_ boxes: [TextBox]) -> Bool {
        let labels = boxes.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard labels.count >= 10 else { return false }
        let hits = labels.filter { Self.homeIconNames.contains($0) }.count
        let short = labels.filter { $0.count <= 8 }.count
        let long = labels.filter { $0.count >= 12 }.count
        let bottom = boxes.filter { $0.boundingBox.midY < 0.18 }.count
        return hits >= 3 && short >= 8 && long == 0 && Double(short) / Double(labels.count) >= 0.8 && bottom >= 3
    }

    private static let homeIconNames: Set<String> = [
        "设置", "相机", "电话", "信息", "邮件", "时钟", "天气", "地图", "照片",
        "音乐", "日历", "备忘录", "文件", "健康", "钱包", "图书", "播客",
        "快捷指令", "翻译", "查找", "通讯录", "计算器", "家庭", "提醒事项",
        "指南针", "测距仪", "放大镜", "股市", "语音备忘录", "FaceTime",
        "Settings", "Camera", "Phone", "Messages", "Mail", "Clock", "Weather",
        "Maps", "Photos", "Music", "Calendar", "Notes", "Files", "Health",
        "Wallet", "Books", "Podcasts", "Shortcuts", "Translate", "Safari",
        "App Store"
    ]

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
            merged = mangaFocusText(from: boxes, settings: settings)
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

    /// Japanese layout follows the current crop (smart / custom / full), not smart-mode only.
    private func mangaFocusText(from boxes: [TextBox], settings: AppSettings) -> String {
        let layout = settings.mangaLayout
        let usable = boxes.filter { !isMangaJunk($0) && looksLikeSourceScript($0.text, source: settings.sourceLanguage) }
        guard !usable.isEmpty else { return "" }
        if layout == .korean {
            let bubbles = clusterBubbles(usable, mergeColumns: true)
                .sorted { mangaOrder($0, $1, layout: .korean) }
            return bubbles.prefix(1)
                .map { reconstructHorizontal($0, joiner: " ") }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        let balloons = japaneseBalloons(from: usable)
        let limit = settings.recognitionMode == .smart ? 2 : min(3, max(balloons.count, 1))
        let texts = Array(balloons.prefix(limit)).filter { !$0.isEmpty }
        if texts.count <= 1 { return texts.first ?? "" }
        return texts.enumerated().map { "【\($0.offset + 1)】\($0.element)" }.joined(separator: "\n")
    }

    private func mangaOrder(_ a: [TextBox], _ b: [TextBox], layout: MangaLayout) -> Bool {
        let ra = bubbleRect(a)
        let rb = bubbleRect(b)
        switch layout {
        case .japanese:
            if abs(ra.midX - rb.midX) > 0.08 {
                return ra.midX > rb.midX
            }
            return ra.midY > rb.midY
        case .korean:
            if abs(ra.midY - rb.midY) > 0.08 {
                return ra.midY > rb.midY
            }
            return ra.midX < rb.midX
        }
    }

    private func isMangaJunk(_ box: TextBox) -> Bool {
        let text = box.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        if box.confidence < 0.30 { return true }
        if text.contains("/") && text.contains(where: \.isNumber) { return true }
        let letters = text.unicodeScalars.filter {
            CharacterSet.letters.contains($0)
                || (0x3040...0x30FF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0xAC00...0xD7AF).contains($0.value)
        }
        let digits = text.filter(\.isNumber)
        if !digits.isEmpty && letters.isEmpty && text.count <= 6 {
            return true
        }
        let compact = text.replacingOccurrences(of: "！", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: "?", with: "")
        if compact.count <= 1, max(box.boundingBox.width, box.boundingBox.height) > 0.14 {
            return true
        }
        return false
    }

    private func looksLikeSourceScript(_ text: String, source: String) -> Bool {
        if text.count <= 2 { return true }
        switch source {
        case "ja": return looksLikeJapanese(text)
        case "ko": return looksLikeHangul(text)
        case "zh-Hans", "zh-Hant": return looksLikeJapanese(text)
        default: return true
        }
    }

    private func looksLikeJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xFF66...0xFF9D).contains(scalar.value)
        }
    }

    private func looksLikeHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0xAC00...0xD7AF).contains($0.value) || (0x1100...0x11FF).contains($0.value) }
    }

    private func clusterBubbles(_ boxes: [TextBox], mergeColumns: Bool) -> [[TextBox]] {
        var remaining = boxes
        var clusters: [[TextBox]] = []
        while let seed = remaining.first {
            remaining.removeFirst()
            var cluster = [seed]
            var changed = true
            while changed {
                changed = false
                remaining.removeAll { box in
                    if cluster.contains(where: { boxesAreNear($0, box, tight: !mergeColumns) }) {
                        cluster.append(box)
                        changed = true
                        return true
                    }
                    return false
                }
            }
            clusters.append(cluster)
        }
        return mergeColumns ? mergeColumnClusters(clusters) : clusters
    }

    private func boxesAreNear(_ a: TextBox, _ b: TextBox, tight: Bool) -> Bool {
        let ra = a.boundingBox
        let rb = b.boundingBox
        let dx = max(0, max(ra.minX - rb.maxX, rb.minX - ra.maxX))
        let dy = max(0, max(ra.minY - rb.maxY, rb.minY - ra.maxY))
        let gap = hypot(dx, dy)
        let scale = max(tight ? 0.032 : 0.04, min(ra.height + rb.height, ra.width + rb.width) * (tight ? 0.7 : 0.55))
        if gap < scale { return true }
        if tight {
            let stacked = abs(ra.midX - rb.midX) < max(0.022, max(ra.width, rb.width) * 1.05)
                && dy < max(0.045, max(ra.height, rb.height) * 1.5)
            let sideBySide = abs(ra.midY - rb.midY) < max(0.035, max(ra.height, rb.height) * 1.15)
                && dx < max(0.038, max(ra.width, rb.width) * 1.7)
            return stacked || sideBySide
        }
        let overlapX = min(ra.maxX, rb.maxX) - max(ra.minX, rb.minX)
        let sameColumn = overlapX > min(ra.width, rb.width) * 0.35
            || abs(ra.midX - rb.midX) < max(0.045, max(ra.width, rb.width) * 0.9)
        let closeVertically = dy < max(0.08, max(ra.height, rb.height) * 1.8)
        return sameColumn && closeVertically
    }

    /// Korean/Japanese bubbles often split into two far-apart lines in one balloon.
    private func mergeColumnClusters(_ clusters: [[TextBox]]) -> [[TextBox]] {
        guard clusters.count > 1 else { return clusters }
        var merged = clusters
        var changed = true
        while changed {
            changed = false
            outer: for i in 0..<merged.count {
                for j in (i + 1)..<merged.count {
                    if columnClustersAlign(merged[i], merged[j]) {
                        merged[i].append(contentsOf: merged[j])
                        merged.remove(at: j)
                        changed = true
                        break outer
                    }
                }
            }
        }
        return merged
    }

    private func columnClustersAlign(_ a: [TextBox], _ b: [TextBox]) -> Bool {
        let ra = bubbleRect(a)
        let rb = bubbleRect(b)
        let overlapX = min(ra.maxX, rb.maxX) - max(ra.minX, rb.minX)
        let sameColumn = overlapX > min(ra.width, rb.width) * 0.28
            || abs(ra.midX - rb.midX) < 0.06
        let gapY = max(0, max(ra.minY - rb.maxY, rb.minY - ra.maxY))
        return sameColumn && gapY < 0.16 && max(ra.width, rb.width) < 0.42
    }

    private func bubbleRect(_ boxes: [TextBox]) -> CGRect {
        boxes.map(\.boundingBox).reduce(into: boxes[0].boundingBox) { $0 = $0.union($1) }
    }

    private func japaneseBalloons(from boxes: [TextBox]) -> [String] {
        let columns = groupJapaneseColumns(splitRowArtifacts(boxes))
        let balloons = groupJapaneseBalloons(columns)
        return balloons.compactMap { balloon -> String? in
            let text = readJapaneseBalloon(balloon)
            return text.isEmpty ? nil : text
        }
    }

    /// A wide ML Kit/Vision line is usually one visual row across several vertical columns.
    /// Place each character by its box, never by the engine's LTR string order.
    private func splitRowArtifacts(_ boxes: [TextBox]) -> [TextBox] {
        boxes.flatMap { box -> [TextBox] in
            let chars = Array(box.text).filter { !$0.isWhitespace && !$0.isNewline }
            let rect = box.boundingBox
            if chars.count <= 1 { return [box] }
            if rect.height > rect.width * 1.25 { return [box] }
            if rect.width > rect.height * 2.2, rect.height < 0.07 { return [box] }
            let width = rect.width / CGFloat(chars.count)
            return chars.enumerated().map { index, ch in
                TextBox(
                    text: String(ch),
                    boundingBox: CGRect(
                        x: rect.minX + width * CGFloat(index),
                        y: rect.minY,
                        width: width,
                        height: rect.height
                    ),
                    confidence: box.confidence
                )
            }
        }
    }

    private func groupJapaneseColumns(_ boxes: [TextBox]) -> [[TextBox]] {
        let widths = boxes.map(\.boundingBox.width).sorted()
        let medianW = max(0.010, widths[widths.count / 2])
        let columnWidth = max(medianW * 1.15, 0.018)
        let sorted = boxes.sorted { $0.boundingBox.midX > $1.boundingBox.midX }
        var columns: [[TextBox]] = []
        for box in sorted {
            if let index = columns.firstIndex(where: { column in
                let refX = column.map(\.boundingBox.midX).reduce(0, +) / CGFloat(column.count)
                return abs(box.boundingBox.midX - refX) < columnWidth
            }) {
                columns[index].append(box)
            } else {
                columns.append([box])
            }
        }
        return columns
            .map { dropAttachedFurigana($0) }
            .filter { !$0.isEmpty }
            .sorted { a, b in
                let xa = a.map(\.boundingBox.midX).reduce(0, +) / CGFloat(a.count)
                let xb = b.map(\.boundingBox.midX).reduce(0, +) / CGFloat(b.count)
                return xa > xb
            }
    }

    private func dropAttachedFurigana(_ column: [TextBox]) -> [TextBox] {
        guard column.count >= 3 else { return column }
        let widths = column.map(\.boundingBox.width).sorted()
        let heights = column.map(\.boundingBox.height).sorted()
        let medianW = widths[widths.count / 2]
        let medianH = heights[heights.count / 2]
        let mainX = column.map(\.boundingBox.midX).reduce(0, +) / CGFloat(column.count)
        return column.filter { box in
            let small = box.boundingBox.width < medianW * 0.58 && box.boundingBox.height < medianH * 0.7
            let beside = abs(box.boundingBox.midX - mainX) > medianW * 0.28
            if small && beside && isMostlyHiragana(box.text) {
                return false
            }
            return true
        }
    }

    private func isMostlyHiragana(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
                && !CharacterSet.punctuationCharacters.contains($0)
        }
        guard !scalars.isEmpty else { return false }
        let hira = scalars.filter { (0x3040...0x309F).contains($0.value) }.count
        return Double(hira) / Double(scalars.count) >= 0.7
    }

    private func groupJapaneseBalloons(_ columns: [[TextBox]]) -> [[[TextBox]]] {
        guard !columns.isEmpty else { return [] }
        var balloons: [[[TextBox]]] = [[columns[0]]]
        for column in columns.dropFirst() {
            let previous = balloons[balloons.count - 1].last!
            if japaneseColumnsShareBalloon(previous, column) {
                balloons[balloons.count - 1].append(column)
            } else {
                balloons.append([column])
            }
        }
        return balloons
    }

    private func japaneseColumnsShareBalloon(_ a: [TextBox], _ b: [TextBox]) -> Bool {
        let ra = bubbleRect(a)
        let rb = bubbleRect(b)
        let gapX = max(0, max(ra.minX - rb.maxX, rb.minX - ra.maxX))
        let overlapY = min(ra.maxY, rb.maxY) - max(ra.minY, rb.minY)
        let enoughOverlap = overlapY > min(ra.height, rb.height) * 0.28
        let close = gapX < max(0.045, min(ra.width, rb.width) * 1.8)
        return enoughOverlap && close
    }

    private func readJapaneseBalloon(_ columns: [[TextBox]]) -> String {
        let rect = bubbleRect(columns.flatMap { $0 })
        let text = columns.flatMap { $0 }.map(\.text).joined()
        if rect.width > rect.height * 2.2, rect.height < 0.07, text.count >= 3 {
            return reconstructHorizontal(columns.flatMap { $0 }, joiner: "")
        }
        return columns.map { column in
            column.sorted { $0.boundingBox.midY > $1.boundingBox.midY }.map(\.text).joined()
        }.joined()
    }

    private func reconstructHorizontal(_ boxes: [TextBox], joiner: String) -> String {
        let lines = groupIntoLines(boxes)
        return lines.map { $0.map(\.text).joined(separator: joiner) }.joined(separator: joiner)
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

    private func recognizePass(
        _ image: CGImage,
        languages: [String],
        accurate: Bool,
        minHeight: Float,
        cropRect: CGRect,
        fullSize: CGSize
    ) throws -> [TextBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = minHeight
        request.recognitionLanguages = languages
        if VNRecognizeTextRequest.supportedRevisions.contains(VNRecognizeTextRequestRevision3) {
            request.revision = VNRecognizeTextRequestRevision3
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 1 else { return nil }
            return TextBox(
                text: text,
                boundingBox: mapBox(observation.boundingBox, cropRect: cropRect, fullSize: fullSize),
                confidence: candidate.confidence
            )
        }
    }

    private func ocrLanguages(settings: AppSettings) -> [String] {
        preferredLanguages(source: settings.sourceLanguage)
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
            return ["en-US", "zh-Hans", "ja-JP", "ko-KR"]
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
            return smartBand(in: size, settings: settings)
        }
    }

    private func smartBand(in size: CGSize, settings: AppSettings) -> CGRect {
        let landscape = size.width > size.height
        switch settings.translateScene {
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
            if settings.mangaLayout == .japanese {
                return OCRRegion(x: 0.06, y: 0.32, width: 0.88, height: 0.36).pixelRect(in: size)
            }
            return CGRect(origin: .zero, size: size)
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
