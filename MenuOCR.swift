import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct MenuOCR {
    enum OCRError: LocalizedError {
        case invalidImage
        case unableToProcess
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Не удалось открыть изображение. Попробуйте выбрать другое фото."
            case .unableToProcess: return "Не удалось распознать текст на изображении."
            }
        }
    }

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Локальное улучшение контраста и резкости перед распознаванием Vision.
    static func preprocessImage(_ image: UIImage) -> UIImage {
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = image.scale
        let upright = UIGraphicsImageRenderer(size: image.size, format: rendererFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let sourceCGImage = upright.cgImage else { return image }
        let source = CIImage(cgImage: sourceCGImage)

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = source
        guard let grayscale = mono.outputImage else { return image }

        let controls = CIFilter.colorControls()
        controls.inputImage = grayscale
        controls.contrast = 1.5
        controls.saturation = 0
        controls.brightness = 0
        guard let contrasted = controls.outputImage else { return image }

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = contrasted
        sharpen.sharpness = 0.5
        guard let output = sharpen.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    /// Распознавание и фильтры выполняются в фоне; сеть не используется.
    static func recognizeText(from image: UIImage) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let prepared = preprocessImage(image)
                    guard let cgImage = prepared.cgImage else { throw OCRError.invalidImage }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.minimumTextHeight = 0.008

                    // Оставляем из языков Vision только запрошенные и доступные на этой версии iOS.
                    let desired = ["ru", "en", "uk", "be", "de", "fr", "it", "es"]
                    if let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty {
                        request.recognitionLanguages = supported.filter { language in
                            let prefix = language.split(separator: "-").first.map(String.init) ?? language
                            return desired.contains(prefix)
                        }
                    }

                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    let observations = request.results ?? []
                    let ordered = observations.compactMap { observation -> (String, Float, CGRect)? in
                        guard let candidate = observation.topCandidates(1).first, candidate.confidence > 0.3 else { return nil }
                        return (candidate.string, candidate.confidence, observation.boundingBox)
                    }.sorted { $0.2.midY > $1.2.midY }
                    continuation.resume(returning: ordered.map { $0.0 }.joined(separator: "\n"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Контекстный разбор цен/названий и заголовков категорий для строк меню.
    static func parseMenuItems(from text: String) -> [ParsedMenuItem] {
        let pattern = #"^(.+?)\s+(\d{1,5}(?:[.,]\d{1,2})?)\s*(руб\.?|р\.?|₽|грн|₴|\$|€)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        var result: [ParsedMenuItem] = []
        var currentCategory = "Без категории"
        let knownCategories = ["закуски", "салаты", "супы", "горячее", "горячие блюда", "десерты", "напитки", "паста", "завтраки", "основные блюда", "гарниры", "соусы", "выпечка", "алкоголь"]

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line),
               let priceRange = Range(match.range(at: 2), in: line) {
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "·—–-•."))
                let priceString = String(line[priceRange]).replacingOccurrences(of: ",", with: ".")
                let hasLetters = name.rangeOfCharacter(from: .letters) != nil
                if name.count >= 2, hasLetters, let price = Double(priceString), price > 0 {
                    result.append(ParsedMenuItem(name: name, price: price, category: currentCategory))
                    continue
                }
            }
            // Заголовки категорий: известные рубрики или короткая строка в верхнем регистре.
            let normalized = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":—–-• "))
            let letters = line.filter(\.isLetter)
            let uppercaseRatio = letters.isEmpty ? 0 : Double(letters.filter(\.isUppercase).count) / Double(letters.count)
            if !line.contains(where: \.isNumber), line.count <= 42, letters.count >= 3,
               knownCategories.contains(where: { normalized == $0 || normalized.hasPrefix($0 + " ") }) || uppercaseRatio > 0.78 {
                currentCategory = line.trimmingCharacters(in: CharacterSet(charactersIn: ":—–-• "))
            }
        }
        return result
    }
}
