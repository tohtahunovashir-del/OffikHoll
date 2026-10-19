import XCTest
@testable import OffikHoll

final class MenuImportServiceTests: XCTestCase {
    private let service = MenuImportService()

    private func row(
        _ name: String,
        _ price: String,
        category: String = "Салаты",
        included: Bool = true
    ) -> ScanDraft {
        ScanDraft(
            name: name,
            priceText: price,
            categoryName: category,
            confidence: 0.9,
            isIncluded: included
        )
    }

    // MARK: - prepare

    func testPrepareKeepsOnlyValidCheckedRows() {
        let rows = [
            row("Цезарь", "520"),
            row("Цезарь", "520"),                      // duplicate inside the scan
            row("Борщ", "0"),                          // price must be > 0
            row("А", "100"),                           // name must be >= 2 chars
            row("Тирамису", "420", included: false)    // unchecked by the waiter
        ]

        let prepared = service.prepare(rows)

        XCTAssertEqual(prepared.drafts.count, 1)
        XCTAssertEqual(prepared.drafts.first?.name, "Цезарь")
        XCTAssertEqual(prepared.drafts.first?.price, 520)
        XCTAssertEqual(prepared.drafts.first?.categoryName, "Салаты")

        XCTAssertEqual(prepared.duplicates, 1)
        XCTAssertEqual(prepared.invalidRows, 2)
        XCTAssertEqual(prepared.uncheckedRows, 1)
        XCTAssertFalse(prepared.isEmpty)
    }

    func testPrepareTrimsAndFallsBackToDefaultCategory() {
        let prepared = service.prepare([row("  Сырники  ", "390", category: "   ")])

        XCTAssertEqual(prepared.drafts.count, 1)
        XCTAssertEqual(prepared.drafts.first?.name, "Сырники")
        XCTAssertEqual(prepared.drafts.first?.categoryName, "Разное")
    }

    func testPrepareIsEmptyWhenNothingSelected() {
        let prepared = service.prepare([
            row("Цезарь", "520", included: false),
            row("Борщ", "420", included: false)
        ])

        XCTAssertTrue(prepared.isEmpty)
        XCTAssertEqual(prepared.drafts.count, 0)
        XCTAssertEqual(prepared.uncheckedRows, 2)
    }

    func testPrepareBuildsDetailsFromPortion() {
        var draft = row("Цезарь", "520")
        draft.portion = "230 г"

        let prepared = service.prepare([draft])

        XCTAssertEqual(prepared.drafts.first?.details, "Порция: 230 г")
    }

    func testPrepareWithoutPortionHasEmptyDetails() {
        let prepared = service.prepare([row("Цезарь", "520")])
        XCTAssertEqual(prepared.drafts.first?.details, "")
    }

    // MARK: - Duplicates

    func testDuplicateIDsFlagLaterRowsOnly() {
        let rows = [
            row("Цезарь", "520"),
            row("Цезарь", "600"),
            row("Борщ", "420", category: "Супы")
        ]

        let ids = service.duplicateIDs(in: rows)

        XCTAssertEqual(ids, [rows[1].id])
    }

    func testSameNameInDifferentCategoriesIsNotDuplicate() {
        let rows = [
            row("Лимонад", "320", category: "Напитки"),
            row("Лимонад", "320", category: "Бар")
        ]

        XCTAssertTrue(service.duplicateIDs(in: rows).isEmpty)
    }

    // MARK: - Categories & search

    func testCategorySuggestionsMergeExistingScannedAndFallback() {
        let existing = [Category(name: "Салаты", order: 0, icon: "leaf.fill")]
        let rows = [
            row("Цезарь", "520", category: "Салаты"),
            row("Пицца", "700", category: "Пицца")
        ]

        let suggestions = service.categorySuggestions(for: rows, existing: existing)

        XCTAssertEqual(suggestions.first, "Салаты", "сначала идут категории заведения")
        XCTAssertTrue(suggestions.contains("Пицца"))
        XCTAssertTrue(suggestions.contains("Разное"))
        XCTAssertEqual(Set(suggestions).count, suggestions.count, "без повторов")
    }

    func testScannedCategoryNamesAreUniqueAndOrdered() {
        let rows = [
            row("Цезарь", "520", category: "Салаты"),
            row("Греческий", "460", category: "Салаты"),
            row("Борщ", "420", category: "Супы")
        ]

        XCTAssertEqual(service.scannedCategoryNames(in: rows), ["Салаты", "Супы"])
    }

    func testLowConfidenceCount() {
        var sure = row("Цезарь", "520")
        sure.confidence = 0.93
        var shaky = row("Борщ", "420")
        shaky.confidence = 0.4

        XCTAssertEqual(service.lowConfidenceCount(in: [sure, shaky]), 1)
    }

    // MARK: - Normalisation

    func testNormalizedKeyIgnoresCaseSpacesAndYo() {
        XCTAssertEqual(
            service.normalizedKey("  Ёлка   Палки "),
            service.normalizedKey("елка палки")
        )
        XCTAssertEqual(service.normalizedKey("Цезарь"), "цезарь")
    }

    func testNormalizedCategoryFallsBackToRaznoe() {
        XCTAssertEqual(service.normalizedCategory("   "), "Разное")
        XCTAssertEqual(service.normalizedCategory(" Супы "), "Супы")
    }
}
