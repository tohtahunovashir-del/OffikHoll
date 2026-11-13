import Foundation
import XCTest
@testable import Bloknot

final class PriceParserTests: XCTestCase {
    func testPlainNumber() {
        XCTAssertEqual(PriceParser.value(from: "450") ?? 0, 450)
    }

    func testDecimalComma() {
        XCTAssertEqual(PriceParser.value(from: "450,50") ?? 0, 450.5)
    }

    func testThousands() {
        XCTAssertEqual(PriceParser.value(from: "1 290 ₽") ?? 0, 1290)
        XCTAssertEqual(PriceParser.value(from: "1 290,50") ?? 0, 1290.5)
    }

    func testThousandsWithDot() {
        XCTAssertEqual(PriceParser.value(from: "1.290") ?? 0, 1290)
        XCTAssertEqual(PriceParser.value(from: "1,290") ?? 0, 1290)
    }

    func testCurrencyOnlyIsNil() {
        XCTAssertNil(PriceParser.value(from: "₽"))
        XCTAssertNil(PriceParser.value(from: ""))
        XCTAssertNil(PriceParser.value(from: "дорого"))
    }

    func testEditableRoundTrip() {
        XCTAssertEqual(PriceParser.editable(590), "590")
        XCTAssertEqual(PriceParser.editable(450.5), "450,50")
        XCTAssertEqual(PriceParser.value(from: PriceParser.editable(450.5)) ?? 0, 450.5)
    }
}
