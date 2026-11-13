import CoreImage
import Foundation
import UIKit
import Vision

enum OCRError: LocalizedError {
    case invalidImage
    case noText
    case failed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Не удалось прочитать изображение."
        case .noText:
            return "Не удалось распознать блюда. Попробуйте сфотографировать меню ближе и при хорошем освещении."
        case .failed:
            return "Сканер не смог обработать снимок. Попробуйте ещё раз."
        }
    }
}

/// Пайплайн распознавания меню.
///
/// 1. Приведение к 2048 px по длинной стороне: тяжёлый кадр уменьшается,
///    мелкий снимок из галереи — увеличивается до рабочего размера.
/// 2. Поиск четырёхугольника документа и перспективная коррекция: снимок
///    «под углом» превращается в ровный лист.
/// 3. Grayscale + контраст 1.5 + усиление резкости 0.5.
/// 4. Vision: `.accurate`, revision 3, языки ru/en/uk, словарь меню в `customWords`.
/// 5. Склейка наблюдений в визуальные строки по геометрии.
/// 6. Разбор строк в блюда (`MenuParser`).
///
/// Если после улучшения распознано меньше трёх блюд, повторяем на исходном
/// (неулучшенном) изображении и берём результат, где блюд больше.
final class OCRService {
    static let shared = OCRService()

    private let context = CIContext(options: nil)

    private init() {}

    func recognizeMenu(
        in image: UIImage,
        customWords: [String] = [],
        knownCategories: [String] = []
    ) throws -> [ParsedDish] {
        guard let normalized = Self.normalizedImage(image, maxDimension: Constants.ocrMaxDimension) else {
            throw OCRError.invalidImage
        }

        let rectified = rectifyDocument(normalized) ?? normalized
        let parser = MenuParser()

        var best: [ParsedDish] = []

        if let enhanced = enhance(rectified),
           let observations = try? recognizeText(in: enhanced, customWords: customWords) {
            best = parser.parse(lines: Self.assembleLines(from: observations), knownCategories: knownCategories)
        }

        if best.count < 3,
           let observations = try? recognizeText(in: rectified, customWords: customWords) {
            let fallback = parser.parse(
                lines: Self.assembleLines(from: observations),
                knownCategories: knownCategories
            )
            if fallback.count > best.count {
                best = fallback
            }
        }

        guard !best.isEmpty else { throw OCRError.noText }
        return best
    }

    // MARK: - Image preparation

    static func normalizedImage(_ image: UIImage, maxDimension: CGFloat) -> CGImage? {
        let size = image.size
        guard size.width > 1, size.height > 1 else { return nil }

        let scale = maxDimension / max(size.width, size.height)
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        guard target.width >= 1, target.height >= 1 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }

    private func rectifyDocument(_ cgImage: CGImage) -> CGImage? {
        let request = VNDetectRectanglesRequest(completionHandler: nil)
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumSize = 0.25
        request.minimumAspectRatio = 0.15
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let rectangle = request.results?.first else { return nil }

        let input = CIImage(cgImage: cgImage)
        let size = input.extent.size

        func point(_ normalized: CGPoint) -> CIVector {
            CIVector(x: normalized.x * size.width, y: normalized.y * size.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(point(rectangle.topLeft), forKey: "inputTopLeft")
        filter.setValue(point(rectangle.topRight), forKey: "inputTopRight")
        filter.setValue(point(rectangle.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(point(rectangle.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        return context.createCGImage(output, from: output.extent)
    }

    private func enhance(_ cgImage: CGImage) -> CGImage? {
        var image = CIImage(cgImage: cgImage)

        image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.5,
            kCIInputBrightnessKey: 0.02
        ])
        image = image.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.5
        ])

        return context.createCGImage(image, from: image.extent)
    }

    // MARK: - Vision

    private func recognizeText(
        in cgImage: CGImage,
        customWords: [String]
    ) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.automaticallyDetectsLanguage = false
        // Ноль, а не 0.02: при 2048 px порог 0.02 отсекает строки высотой
        // меньше 40 px, то есть половину обычного печатного меню.
        request.minimumTextHeight = 0

        if !customWords.isEmpty {
            request.customWords = Array(Set(customWords)).sorted()
        }

        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let preferred = ["ru-RU", "en-US", "uk-UA"]
        let available = preferred.filter { supported.contains($0) }
        request.recognitionLanguages = available.isEmpty ? ["ru-RU", "en-US"] : available

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    // MARK: - Line assembly

    static func assembleLines(from observations: [VNRecognizedTextObservation]) -> [RecognizedLine] {
        var segments: [RecognizedSegment] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            segments.append(
                RecognizedSegment(
                    text: text,
                    confidence: candidate.confidence,
                    box: observation.boundingBox
                )
            )
        }

        guard !segments.isEmpty else { return [] }
        segments.sort { $0.box.midY > $1.box.midY }

        var rows: [[RecognizedSegment]] = []
        for segment in segments {
            if let index = rows.firstIndex(where: { row in
                guard let first = row.first else { return false }
                let rowBox = row.dropFirst().reduce(first.box) { $0.union($1.box) }
                let overlap = min(rowBox.maxY, segment.box.maxY) - max(rowBox.minY, segment.box.minY)
                let minHeight = min(rowBox.height, segment.box.height)
                return overlap > minHeight * 0.4
            }) {
                rows[index].append(segment)
            } else {
                rows.append([segment])
            }
        }

        return rows.map { row -> RecognizedLine in
            let ordered = row.sorted { $0.box.minX < $1.box.minX }
            let text = ordered.map(\.text).joined(separator: " ")
            let firstBox = ordered[0].box
            let box = ordered.dropFirst().reduce(firstBox) { $0.union($1.box) }

            let totalWeight = ordered.reduce(0) { $0 + max(1, $1.text.count) }
            let weighted = ordered.reduce(Float(0)) { partial, segment in
                partial + segment.confidence * Float(max(1, segment.text.count))
            } / Float(max(1, totalWeight))

            return RecognizedLine(text: text, confidence: weighted, box: box, segments: ordered)
        }
        .sorted { $0.box.midY > $1.box.midY }
    }
}
