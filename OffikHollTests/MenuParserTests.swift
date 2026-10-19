import XCTest
@testable import OffikHoll

/// Regression tests for the OCR → structure stage. Every string here is a
/// realistic printed-menu line, including the messy variants Vision produces.
final class MenuParserTests: XCTestCase {
    private let parser = MenuParser()

    // MARK: - Prices

    func testTrailingPriceWithCategoryHeaders() {
        let items = parser.parse(text: """
        САЛАТЫ
        Цезарь с курицей 520
        Греческий салат ........ 460
        СУПЫ
        Борщ с говядиной .... 420 ₽
        """)

        XCTAssertEqual(items.count, 3)

        XCTAssertEqual(items[0].name, "Цезарь с курицей")
        XCTAssertEqual(items[0].price, 520)
        XCTAssertEqual(items[0].categoryName, "Салаты")

        XCTAssertEqual(items[1].name, "Греческий салат")
        XCTAssertEqual(items[1].price, 460)
        XCTAssertEqual(items[1].categoryName, "Салаты")

        XCTAssertEqual(items[2].name, "Борщ с говядиной")
        XCTAssertEqual(items[2].price, 420)
        XCTAssertEqual(items[2].currency, "₽")
        XCTAssertEqual(items[2].categoryName, "Супы")
    }

    func testThousandsSeparator() {
        let items = parser.parse(text: """
        ГРИЛЬ
        Стейк рибай 1 890 ₽
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Стейк рибай")
        XCTAssertEqual(items[0].price, 1890)
        XCTAssertEqual(items[0].categoryName, "Гриль")
    }

    func testLeadingPrice() {
        let items = parser.parse(text: "320 Домашний лимонад")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Домашний лимонад")
        XCTAssertEqual(items[0].price, 320)
    }

    func testSizeBeforePrice() {
        let items = parser.parse(text: "Домашний лимонад 0.5 320")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Домашний лимонад")
        XCTAssertEqual(items[0].portion, "0.5")
        XCTAssertEqual(items[0].price, 320)
    }

    func testForeignCurrencyIsPreserved() {
        let items = parser.parse(text: "Паста карбонара 12 €")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].price, 12)
        XCTAssertEqual(items[0].currency, "€")
    }

    // MARK: - Noise, bullets, duplicates

    func testNoiseAndSingleWordHeadersIgnored() {
        let items = parser.parse(text: """
        МЕНЮ
        Спасибо за визит
        Итого 1250
        Тирамису 420
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Тирамису")
        XCTAssertEqual(items[0].price, 420)
    }

    func testBulletsAndNumberingStripped() {
        let items = parser.parse(text: """
        • Тирамису 420
        2. Медовик 340
        """)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, "Тирамису")
        XCTAssertEqual(items[1].name, "Медовик")
        XCTAssertEqual(items[1].price, 340)
    }

    func testDuplicatesAcrossPagesCollapsed() {
        let items = parser.parse(text: """
        Тирамису 420
        Тирамису 420
        """)

        XCTAssertEqual(items.count, 1)
    }

    // MARK: - Wrapped names

    func testWrappedNameWithoutCurrency() {
        let items = parser.parse(text: """
        Тёплый салат с уткой и
        хрустящими баклажанами ..... 720
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].price, 720)
        XCTAssertTrue(items[0].name.contains("баклажан"), items[0].name)
    }

    /// Regression: a continuation line with an explicit currency used to be
    /// dropped by the `canBeWrappedName` guard, losing the whole dish.
    func testWrappedNameWithCurrency() {
        let items = parser.parse(text: """
        Тёплый салат с уткой и
        хрустящими баклажанами ..... 720 ₽
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].price, 720)
        XCTAssertEqual(items[0].name, "Тёплый салат с уткой и хрустящими баклажанами")
    }

    /// A short unknown header must not be glued to the complete dish row
    /// that follows it.
    func testShortHeaderIsNotGluedToNextDish() {
        let items = parser.parse(text: """
        Дополнительно
        Хлеб 100 ₽
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Хлеб")
        XCTAssertEqual(items[0].price, 100)
    }

    // MARK: - Confidence & metadata

    func testConfidenceStaysInRange() {
        let items = parser.parse(text: """
        САЛАТЫ
        Цезарь с курицей 520 ₽
        """)

        XCTAssertEqual(items.count, 1)
        XCTAssertGreaterThan(items[0].confidence, 0)
        XCTAssertLessThanOrEqual(items[0].confidence, 0.99)
    }

    func testRecognizedLinesKeepPageIndexAndOrder() {
        let lines = [
            RecognizedLine(text: "САЛАТЫ", confidence: 0.95, pageIndex: 0),
            RecognizedLine(text: "Цезарь с курицей 520", confidence: 0.9, pageIndex: 0),
            RecognizedLine(text: "Тирамису 420", confidence: 0.85, pageIndex: 1)
        ]
        let items = parser.parse(lines: lines)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].pageIndex, 0)
        XCTAssertEqual(items[1].pageIndex, 1)
    }

    /// A header that matches a category the restaurant already has must reuse
    /// that exact category (including its spelling), not the built-in hint.
    func testExistingCategoryNamesWinOverHints() {
        let items = parser.parse(
            text: """
            САЛАТЫ ДНЯ
            Цезарь с курицей 520
            """,
            existingCategories: ["Салаты дня"]
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].categoryName, "Салаты дня")
    }

    func testEmptyInputProducesNothing() {
        XCTAssertTrue(parser.parse(text: "").isEmpty)
        XCTAssertTrue(parser.parse(text: "\n\n   \n").isEmpty)
        XCTAssertTrue(parser.parse(lines: []).isEmpty)
    }
}
