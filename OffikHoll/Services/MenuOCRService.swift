import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Не удалось подготовить изображение для распознавания."
        }
    }
}

/// Offline OCR pipeline for menu photos.
///
/// Stage 1 — preprocess: normalise orientation, downscale, grayscale,
/// highlight contrast, sharpen. (Note: the filter is `CIColorControls`,
/// because `CIContrast` from the previous implementation does not exist in
/// Core Image.)
/// Stage 2 — recognise: Vision `.accurate`, language correction and a wide
/// Cyrillic/Latin language set; automatic fallback to ru/en if a language is
/// not installed on the device.
/// Stage 3 — layout: group Vision boxes into visual rows and split columns by
/// horizontal gaps, producing a natural reading order.
/// Stage 4 — parse: `MenuParser` turns those lines into editable dishes.
final class MenuOCRService {
    static let preferredLanguages = [
        "ru-RU", "en-US", "uk-UA", "be-BY", "de-DE", "fr-FR", "it-IT", "es-ES"
    ]

    func recognizeLines(
        in image: UIImage,
        pageIndex: Int,
        customWords: [String] = []
    ) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let normalized = Self.normalizedImage(image)
            let enhanced = Self.enhancedImage(normalized)
            var lines = try Self.recognizeText(
                in: enhanced,
                pageIndex: pageIndex,
                customWords: customWords
            )
            if lines.count < 3 {
                let rawLines = try Self.recognizeText(
                    in: normalized,
                    pageIndex: pageIndex,
                    customWords: customWords
                )
                if rawLines.count > lines.count {
                    lines = rawLines
                }
            }
            return lines
        }.value
    }

    // MARK: - Stage 1: preprocessing

    private static func normalizedImage(_ image: UIImage, maxDimension: CGFloat = 3600) -> UIImage {
        let width = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let height = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        let longest = max(width, height)
        guard longest > 0 else { return image }
        let ratio = min(1, maxDimension / longest)
        let target = CGSize(
            width: max(1, image.size.width * ratio),
            height: max(1, image.size.height * ratio)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func enhancedImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        var output = input

        if let mono = CIFilter(name: "CIPhotoEffectMono") {
            mono.setValue(output, forKey: kCIInputImageKey)
            if let result = mono.outputImage { output = result }
        }
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey)
            controls.setValue(1.35, forKey: kCIInputContrastKey)
            controls.setValue(0.03, forKey: kCIInputBrightnessKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            if let result = controls.outputImage { output = result }
        }
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(output.clampedToExtent(), forKey: kCIInputImageKey)
            sharpen.setValue(0.55, forKey: kCIInputSharpnessKey)
            if let result = sharpen.outputImage {
                output = result.cropped(to: input.extent)
            }
        }
        guard let rendered = context.createCGImage(output, from: input.extent) else {
            return image
        }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: .up)
    }

    // MARK: - Stage 2: Vision

    private static func recognizeText(
        in image: UIImage,
        pageIndex: Int,
        customWords: [String]
    ) throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Only hand Vision the languages this device actually installed.
        // Passing an unsupported identifier can raise an Objective-C exception
        // that Swift cannot catch, which would kill the whole scan.
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let available = Self.preferredLanguages.filter { supported.contains($0) }
        request.recognitionLanguages = available.isEmpty
            ? ["ru-RU", "en-US"]
            : available

        if !customWords.isEmpty {
            request.customWords = Array(customWords.prefix(250))
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Some language packs are optional on-device. Never fail the whole
            // scan because of one missing language.
            request.recognitionLanguages = ["ru-RU", "en-US"]
            try handler.perform([request])
        }

        guard let observations = request.results else { return [] }
        return Self.layoutLines(from: observations, pageIndex: pageIndex)
    }

    // MARK: - Stage 3: layout analysis

    private struct TextBox {
        let text: String
        let confidence: Float
        let rect: CGRect
    }

    private static func layoutLines(
        from observations: [VNRecognizedTextObservation],
        pageIndex: Int
    ) -> [RecognizedLine] {
        let boxes: [TextBox] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return TextBox(text: text, confidence: candidate.confidence, rect: observation.boundingBox)
        }
        guard !boxes.isEmpty else { return [] }

        // Vision uses a bottom-left origin, so larger midY means higher on the page.
        let sorted = boxes.sorted { $0.rect.midY > $1.rect.midY }
        var rows: [[TextBox]] = []
        for box in sorted {
            if let index = rows.firstIndex(where: { row -> Bool in
                guard let anchor = row.first else { return false }
                let tolerance = max(
                    0.008,
                    min(0.022, max(anchor.rect.height, box.rect.height) * 0.65)
                )
                return abs(anchor.rect.midY - box.rect.midY) <= tolerance
            }) {
                rows[index].append(box)
            } else {
                rows.append([box])
            }
        }

        var lines: [RecognizedLine] = []
        for row in rows {
            let ordered = row.sorted { $0.rect.minX < $1.rect.minX }
            var segmentText = ""
            var confidenceSum: Float = 0
            var confidenceCount = 0
            var lastMaxX: CGFloat = -10

            func flushSegment() {
                let trimmed = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let confidence = confidenceCount > 0
                        ? Double(confidenceSum / Float(confidenceCount))
                        : 0.3
                    lines.append(
                        RecognizedLine(
                            text: trimmed,
                            confidence: confidence,
                            pageIndex: pageIndex
                        )
                    )
                }
                segmentText = ""
                confidenceSum = 0
                confidenceCount = 0
            }

            for box in ordered {
                let gap = box.rect.minX - lastMaxX
                if segmentText.isEmpty {
                    segmentText = box.text
                } else if gap <= 0.032 {
                    segmentText += " " + box.text
                } else {
                    flushSegment()
                    segmentText = box.text
                }
                confidenceSum += box.confidence
                confidenceCount += 1
                lastMaxX = max(lastMaxX, box.rect.maxX)
            }
            flushSegment()
        }
        return lines
    }
}
