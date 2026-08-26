import Foundation
import CoreGraphics
import UIKit

#if canImport(MLKitTextRecognition)
import MLKitTextRecognition
import MLKitVision
#if canImport(MLKitTextRecognitionJapanese)
import MLKitTextRecognitionJapanese
#endif
#if canImport(MLKitTextRecognitionKorean)
import MLKitTextRecognitionKorean
#endif
#endif

enum MLKitOCR {
    static var isAvailable: Bool {
        #if canImport(MLKitTextRecognition)
        return true
        #else
        return false
        #endif
    }

    static func recognize(
        image: CGImage,
        layout: MangaLayout,
        cropRect: CGRect,
        fullSize: CGSize
    ) -> [TextBox]? {
        #if canImport(MLKitTextRecognition)
        let uiImage = UIImage(cgImage: image)
        let visionImage = VisionImage(image: uiImage)
        visionImage.orientation = .up
        let recognizer: TextRecognizer
        switch layout {
        case .japanese:
            #if canImport(MLKitTextRecognitionJapanese)
            recognizer = TextRecognizer.textRecognizer(options: JapaneseTextRecognizerOptions())
            #else
            recognizer = TextRecognizer.textRecognizer()
            #endif
        case .korean:
            #if canImport(MLKitTextRecognitionKorean)
            recognizer = TextRecognizer.textRecognizer(options: KoreanTextRecognizerOptions())
            #else
            recognizer = TextRecognizer.textRecognizer()
            #endif
        }
        do {
            let result = try recognizer.results(in: visionImage)
            return result.lines.map { line in
                let frame = line.frame
                let mapped = CGRect(
                    x: (cropRect.minX + frame.minX) / max(fullSize.width, 1),
                    y: 1 - (cropRect.minY + frame.maxY) / max(fullSize.height, 1),
                    width: frame.width / max(fullSize.width, 1),
                    height: frame.height / max(fullSize.height, 1)
                )
                return TextBox(text: line.text.trimmingCharacters(in: .whitespacesAndNewlines), boundingBox: mapped, confidence: 0.92)
            }.filter { !$0.text.isEmpty }
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
