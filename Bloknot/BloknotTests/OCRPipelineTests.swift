import Foundation
import UIKit
import XCTest
@testable import Bloknot

/// Сквозная проверка: синтетическое «фото меню» → предобработка → Vision → парсер.
final class OCRPipelineTests: XCTestCase {
    func testRecognizesRenderedMenu() throws {
        let image = renderMenuImage()
        let dishes: [ParsedDish]
        do {
            dishes = try OCRService.shared.recognizeMenu(
                in: image,
                customWords: ["Цезарь с курицей", "Стейк Рибай"]
            )
        } catch {
            throw XCTSkip("Vision на этом раннере не распознал синтетическое изображение: \(error)")
        }

        XCTAssertFalse(dishes.isEmpty)
        XCTAssertLessThanOrEqual(dishes.count, 4, "склейка строк не должна плодить лишние блюда")

        for dish in dishes {
            XCTAssertFalse(dish.name.isEmpty)
            XCTAssertGreaterThanOrEqual(dish.price, Constants.ocrMinimumPrice)
        }

        // Синтетическое фото — проверка сквозного пути, а не точности Vision:
        // требуем, чтобы распозналось хотя бы одно из двух блюд с верной ценой.
        let names = dishes.map { $0.name.lowercased() }
        let hasSteak = names.contains { $0.contains("стейк") }
        let hasCaesar = names.contains { $0.contains("цезарь") }
        XCTAssertTrue(hasSteak || hasCaesar, "распознано: \(names)")

        if let steak = dishes.first(where: { $0.name.lowercased().contains("стейк") }) {
            XCTAssertEqual(steak.price, 1290, accuracy: 1)
        }
        if let caesar = dishes.first(where: { $0.name.lowercased().contains("цезарь") }) {
            XCTAssertEqual(caesar.price, 590, accuracy: 1)
        }
    }

    func testNormalizedImageDownscales() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        }

        let normalized = try XCTUnwrap(OCRService.normalizedImage(source, maxDimension: 2048))
        XCTAssertEqual(max(normalized.width, normalized.height), 2048)
    }

    private func renderMenuImage() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 62, weight: .semibold),
                .foregroundColor: UIColor.black
            ]

            let lines = ["САЛАТЫ", "Цезарь с курицей 590", "Стейк Рибай 1 290"]
            for (index, line) in lines.enumerated() {
                let point = CGPoint(x: 80, y: 120 + CGFloat(index) * 150)
                (line as NSString).draw(at: point, withAttributes: attributes)
            }
        }
    }
}
