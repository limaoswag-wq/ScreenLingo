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
        sourceLanguage: String,
        cropRect: CGRect,
        fullSize: CGSize
    ) -> [TextBox]? {
        #if canImport(MLKitTextRecognition)
        let uiImage = UIImage(cgImage: image)
        let visionImage = VisionImage(image: uiImage)
        visionImage.orientation = .up
        let recognizer: TextRecognizer
        switch sourceLanguage {
        case "ja":
            #if canImport(MLKitTextRecognitionJapanese)
            recognizer = TextRecognizer.textRecognizer(options: JapaneseTextRecognizerOptions())
            #else
            recognizer = TextRecognizer.textRecognizer()
            #endif
        case "ko":
            #if canImport(MLKitTextRecognitionKorean)
            recognizer = TextRecognizer.textRecognizer(options: KoreanTextRecognizerOptions())
            #else
            recognizer = TextRecognizer.textRecognizer()
            #endif
        default:
            return nil
        }
        do {
            let result = try recognizer.results(in: visionImage)
            var boxes: [TextBox] = []
            for line in result.lines {
                if sourceLanguage == "ja", !line.elements.isEmpty {
                    for element in line.elements {
                        let text = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { continue }
                        boxes.append(
                            TextBox(
                                text: text,
                                boundingBox: mapFrame(element.frame, cropRect: cropRect, fullSize: fullSize),
                                confidence: 0.92
                            )
                        )
                    }
                } else {
                    let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    boxes.append(
                        TextBox(
                            text: text,
                            boundingBox: mapFrame(line.frame, cropRect: cropRect, fullSize: fullSize),
                            confidence: 0.92
                        )
                    )
                }
            }
            return boxes
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func mapFrame(_ frame: CGRect, cropRect: CGRect, fullSize: CGSize) -> CGRect {
        CGRect(
            x: (cropRect.minX + frame.minX) / max(fullSize.width, 1),
            y: 1 - (cropRect.minY + frame.maxY) / max(fullSize.height, 1),
            width: frame.width / max(fullSize.width, 1),
            height: frame.height / max(fullSize.height, 1)
        )
    }
}
