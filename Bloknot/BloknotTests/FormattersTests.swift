import Foundation
import XCTest
@testable import Bloknot

final class FormattersTests: XCTestCase {
    func testMoney() {
        XCTAssertEqual(Money.string(590), "590 ₽")
        XCTAssertEqual(Money.plain(1890), "1 890")
        XCTAssertEqual(Money.string(1890), "1 890 ₽")
    }

    func testPlural() {
        XCTAssertEqual(Plural.positions(1), "1 позиция")
        XCTAssertEqual(Plural.positions(3), "3 позиции")
        XCTAssertEqual(Plural.positions(5), "5 позиций")
        XCTAssertEqual(Plural.positions(11), "11 позиций")
        XCTAssertEqual(Plural.positions(21), "21 позиция")
        XCTAssertEqual(Plural.items(1), "1 блюдо")
        XCTAssertEqual(Plural.items(2), "2 блюда")
        XCTAssertEqual(Plural.guests(5), "5 гостей")
    }

    func testStatusTitles() {
        XCTAssertEqual(TableStatus.free.title, "Свободен")
        XCTAssertEqual(TableStatus.kitchen.title, "На кухне")
        XCTAssertEqual(OrderStatus.open.title, "Новый")
        XCTAssertEqual(OrderStatus.paid.title, "Оплачен")
    }
}
