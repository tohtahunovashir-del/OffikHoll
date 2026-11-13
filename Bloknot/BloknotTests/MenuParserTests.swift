import Foundation
import XCTest
@testable import Bloknot

/// Главный тест приложения: разбор меню.
/// Первые десять кейсов — обязательные из спецификации.
final class MenuParserTests: XCTestCase {
    private let parser = MenuParser()

    private func single(_ text: String) -> ParsedDish? {
        parser.parse(text: text).first
    }

    // MARK: - Обязательные кейсы

    func testSteakWithPrice() {
        let dish = single("Стейк Рибай 1290")
        XCTAssertEqual(dish?.name ?? "", "Стейк Рибай")
        XCTAssertEqual(dish?.price ?? 0, 1290)
    }

    func testLatinName() {
        let dish = single("Pasta Carbonara 450")
        XCTAssertEqual(dish?.name ?? "", "Pasta Carbonara")
        XCTAssertEqual(dish?.price ?? 0, 450)
    }

    func testBareNumberIsNotDish() {
        XCTAssertNil(single("1290"))
        XCTAssertNil(single("450"))
    }

    func testHeaderWithoutPriceIsNotDish() {
        XCTAssertNil(single("Горячие"))
        XCTAssertNil(single("Меню"))
    }

    func testPageMarkerIsNotDish() {
        XCTAssertNil(single("Стр. 2"))
    }

    func testCurrencySuffix() {
        let dish = single("Цезарь с курицей 590 руб.")
        XCTAssertEqual(dish?.name ?? "", "Цезарь с курицей")
        XCTAssertEqual(dish?.price ?? 0, 590)
    }

    func testYearInsideNameIsKept() {
        let dish = single("Chianti Classico 2019 1890")
        XCTAssertEqual(dish?.name ?? "", "Chianti Classico 2019")
        XCTAssertEqual(dish?.price ?? 0, 1890)
    }

    func testSimpleDish() {
        let dish = single("Борщ домашний 420")
        XCTAssertEqual(dish?.name ?? "", "Борщ домашний")
        XCTAssertEqual(dish?.price ?? 0, 420)
    }

    // MARK: - Реальные типы строк

    func testVolumeIsKeptAndNotTreatedAsPrice() {
        let dish = single("Heineken 0.5 350")
        XCTAssertEqual(dish?.name ?? "", "Heineken 0.5")
        XCTAssertEqual(dish?.price ?? 0, 350)
    }

    func testDotLeadersAreRemoved() {
        let dish = single("Цезарь с курицей ......... 590")
        XCTAssertEqual(dish?.name ?? "", "Цезарь с курицей")
        XCTAssertEqual(dish?.price ?? 0, 590)
    }

    func testThousandsWithSpace() {
        let dish = single("Стейк Рибай 1 290 ₽")
        XCTAssertEqual(dish?.name ?? "", "Стейк Рибай")
        XCTAssertEqual(dish?.price ?? 0, 1290)
    }

    func testThousandsWithDot() {
        let dish = single("Стейк 1.290 ₽")
        XCTAssertEqual(dish?.name ?? "", "Стейк")
        XCTAssertEqual(dish?.price ?? 0, 1290)
    }

    func testAttachedCurrency() {
        let dish = single("Цезарь 590руб")
        XCTAssertEqual(dish?.name ?? "", "Цезарь")
        XCTAssertEqual(dish?.price ?? 0, 590)
    }

    func testTrailingPeriod() {
        XCTAssertEqual(single("Борщ 420.")?.price ?? 0, 420)
    }

    func testShortRoubleSuffix() {
        XCTAssertEqual(single("Борщ 420 р")?.price ?? 0, 420)
        XCTAssertEqual(single("Борщ 420 рублей")?.price ?? 0, 420)
        XCTAssertEqual(single("Борщ 420₽")?.price ?? 0, 420)
    }

    func testNoiseTotalIsIgnored() {
        XCTAssertNil(single("Итого 5 810"))
        XCTAssertNil(single("Спасибо за визит"))
        XCTAssertNil(single("https://menu.ru"))
        XCTAssertNil(single("Официант: Иван"))
    }

    func testPriceBeforeNameIsIgnored() {
        XCTAssertNil(single("1290 Стейк Рибай"))
    }

    func testTooCheapPriceIsIgnored() {
        XCTAssertNil(single("Стр. 12"))
        XCTAssertNil(single("Пакет 2"))
    }

    // MARK: - Категории

    func testCategoryHeaderIsApplied() {
        let dishes = parser.parse(text: """
        САЛАТЫ
        Цезарь с курицей 590
        СУПЫ
        Борщ 420
        """)

        XCTAssertEqual(dishes.count, 2)
        XCTAssertEqual(dishes[0].category, "Салаты")
        XCTAssertEqual(dishes[1].category, "Супы")
    }

    func testKnownCategorySpellingWins() {
        let dishes = parser.parse(
            text: """
            САЛАТЫ
            Цезарь 590
            """,
            knownCategories: ["Салаты дня"]
        )
        XCTAssertEqual(dishes.first?.category, "Салаты дня")
    }

    func testDefaultCategory() {
        let dishes = parser.parse(text: "Тартар 120")
        XCTAssertEqual(dishes.first?.category, Constants.defaultCategoryName)
    }

    // MARK: - Переносы и дубликаты

    func testWrappedNameIsMerged() {
        let dishes = parser.parse(text: """
        Тёплый салат с уткой и
        хрустящими баклажанами ..... 720 ₽
        """)

        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.price ?? 0, 720)
        XCTAssertEqual(dishes.first?.name ?? "", "Тёплый салат с уткой и хрустящими баклажанами")
    }

    func testLowercaseContinuationIsMerged() {
        let dishes = parser.parse(text: """
        Домашний лимонад с
        мятой и лаймом 320
        """)

        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.name ?? "", "Домашний лимонад с мятой и лаймом")
    }

    func testSingleWordHeaderIsNotGlued() {
        let dishes = parser.parse(text: """
        Дополнительно
        Хлеб 100
        """)

        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.name ?? "", "Хлеб")
    }

    func testDuplicatesAreCollapsed() {
        let dishes = parser.parse(text: """
        Тирамису 420
        Тирамису 420
        """)
        XCTAssertEqual(dishes.count, 1)
    }

    func testSameNameDifferentPriceIsKept() {
        let dishes = parser.parse(text: """
        Эспрессо 180
        Эспрессо 240
        """)
        XCTAssertEqual(dishes.count, 2)
    }

    // MARK: - Служебное

    func testConfidenceRange() {
        let dish = single("Стейк Рибай 1 290 ₽")
        XCTAssertNotNil(dish)
        XCTAssertGreaterThan(dish?.confidence ?? 0, 0.05)
        XCTAssertLessThanOrEqual(dish?.confidence ?? 1, 0.99)
    }

    func testEmptyInput() {
        XCTAssertTrue(parser.parse(text: "").isEmpty)
        XCTAssertTrue(parser.parse(text: "\n\n   \n").isEmpty)
        XCTAssertTrue(parser.parse(lines: []).isEmpty)
    }

    func testPageOrderIsPreserved() {
        let lines = [
            RecognizedLine(text: "САЛАТЫ", confidence: 0.95, box: CGRect(x: 0, y: 0.9, width: 1, height: 0.04), segments: []),
            RecognizedLine(text: "Цезарь 590", confidence: 0.9, box: CGRect(x: 0, y: 0.8, width: 1, height: 0.04), segments: []),
            RecognizedLine(text: "Борщ 420", confidence: 0.9, box: CGRect(x: 0, y: 0.7, width: 1, height: 0.04), segments: [])
        ]
        let dishes = parser.parse(lines: lines)
        XCTAssertEqual(dishes.map(\.name), ["Цезарь", "Борщ"])
    }
}
