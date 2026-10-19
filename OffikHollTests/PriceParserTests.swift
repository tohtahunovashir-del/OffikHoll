import XCTest
@testable import OffikHoll

final class PriceParserTests: XCTestCase {
    func testPlainInteger() {
        XCTAssertEqual(PriceParser.value(from: "450"), 450)
    }

    func testDecimalComma() {
        XCTAssertEqual(PriceParser.value(from: "450,50"), 450.5)
    }

    func testDecimalDot() {
        XCTAssertEqual(PriceParser.value(from: "450.90"), 450.9)
    }

    func testThousandsSeparatorAndCurrency() {
        XCTAssertEqual(PriceParser.value(from: "1 250 ₽"), 1250)
        XCTAssertEqual(PriceParser.value(from: "1\u{00A0}250\u{00A0}руб."), 1250)
    }

    func testOCRDigitFixes() {
        // "4S0" — S recognised instead of 5.
        XCTAssertEqual(PriceParser.value(from: "4S0"), 450)
        // "1ООО" — Cyrillic О instead of zero.
        XCTAssertEqual(PriceParser.value(from: "1\u{041E}\u{041E}\u{041E}"), 1000)
    }

    func testCurrencyWithoutNumberIsNil() {
        XCTAssertNil(PriceParser.value(from: "₽"))
        XCTAssertNil(PriceParser.value(from: "руб."))
        XCTAssertNil(PriceParser.value(from: ""))
    }

    func testEditableRoundTrip() {
        XCTAssertEqual(PriceParser.editable(450), "450")
        XCTAssertEqual(PriceParser.editable(450.5), "450,50")
        XCTAssertEqual(PriceParser.value(from: PriceParser.editable(450.5)), 450.5)
    }

    func testPriceString() {
        XCTAssertEqual(Price.string(0), "0 ₽")
        XCTAssertEqual(Price.string(0, showCurrency: false), "0")

        let formatted = Price.string(1250).replacingOccurrences(of: "\u{00A0}", with: " ")
        XCTAssertEqual(formatted, "1 250 ₽")
    }

    func testCompactPrice() {
        XCTAssertEqual(Price.compact(320), Price.string(320))
        XCTAssertTrue(Price.compact(24_380).contains("тыс."))
    }
}
