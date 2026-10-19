import XCTest
import SwiftUI
@testable import OffikHoll

final class AppFormatTests: XCTestCase {
    func testRussianPluralRules() {
        XCTAssertEqual(AppFormat.plural(1, "позиция", "позиции", "позиций"), "позиция")
        XCTAssertEqual(AppFormat.plural(2, "позиция", "позиции", "позиций"), "позиции")
        XCTAssertEqual(AppFormat.plural(4, "позиция", "позиции", "позиций"), "позиции")
        XCTAssertEqual(AppFormat.plural(5, "позиция", "позиции", "позиций"), "позиций")
        XCTAssertEqual(AppFormat.plural(11, "позиция", "позиции", "позиций"), "позиций")
        XCTAssertEqual(AppFormat.plural(12, "позиция", "позиции", "позиций"), "позиций")
        XCTAssertEqual(AppFormat.plural(21, "позиция", "позиции", "позиций"), "позиция")
        XCTAssertEqual(AppFormat.plural(22, "позиция", "позиции", "позиций"), "позиции")
        XCTAssertEqual(AppFormat.plural(0, "позиция", "позиции", "позиций"), "позиций")
        XCTAssertEqual(AppFormat.plural(101, "позиция", "позиции", "позиций"), "позиция")
    }

    func testItemsAndGuests() {
        XCTAssertEqual(AppFormat.items(1), "1 позиция")
        XCTAssertEqual(AppFormat.items(3), "3 позиции")
        XCTAssertEqual(AppFormat.items(5), "5 позиций")
        XCTAssertEqual(AppFormat.guests(1), "1 гость")
        XCTAssertEqual(AppFormat.guests(4), "4 гостя")
        XCTAssertEqual(AppFormat.guests(11), "11 гостей")
    }

    func testElapsed() {
        XCTAssertEqual(AppFormat.elapsed(since: nil), "")
        XCTAssertEqual(AppFormat.elapsed(since: Date()), "только что")
        XCTAssertEqual(AppFormat.elapsed(since: Date().addingTimeInterval(-120)), "2 мин")
        XCTAssertEqual(AppFormat.elapsed(since: Date().addingTimeInterval(-3_700)), "1 ч 1 мин")
        XCTAssertEqual(AppFormat.elapsed(since: Date().addingTimeInterval(-7_200)), "2 ч")
    }

    func testTimeAndDayAreNotEmpty() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(AppFormat.time(date).isEmpty)
        XCTAssertFalse(AppFormat.day(date).isEmpty)
        XCTAssertEqual(AppFormat.time(nil), "")
    }

    func testVersionString() {
        XCTAssertFalse(AppFormat.versionString().isEmpty)
    }

    func testPaymentMethodTitles() {
        XCTAssertEqual(PaymentMethod.cash.title, "Наличные")
        XCTAssertEqual(PaymentMethod.card.title, "Карта")
        XCTAssertEqual(PaymentMethod.transfer.title, "Перевод")
        XCTAssertEqual(PaymentMethod.allCases.count, 3)
    }

    func testStatusTitles() {
        XCTAssertEqual(OrderStatus.active.title, "Новый")
        XCTAssertEqual(OrderStatus.sent.title, "На кухне")
        XCTAssertEqual(OrderStatus.paid.title, "Оплачен")
        XCTAssertEqual(TableStatus.free.title, "Свободен")
        XCTAssertEqual(TableStatus.occupied.title, "Занят")
    }

    func testAppearanceModeHasRussianTitles() {
        XCTAssertEqual(AppearanceMode.system.title, "Системная")
        XCTAssertEqual(AppearanceMode.light.title, "Светлая")
        XCTAssertEqual(AppearanceMode.dark.title, "Тёмная")
        XCTAssertNil(AppearanceMode.system.colorScheme)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, ColorScheme.dark)
        XCTAssertEqual(AppearanceMode.allCases.count, 3)
    }

    func testCategoryIconsAreMapped() {
        XCTAssertEqual(CategoryIcons.icon(forCategoryNamed: "Салаты"), "leaf.fill")
        XCTAssertEqual(CategoryIcons.icon(forCategoryNamed: "СУПЫ"), "cup.and.saucer.fill")
        XCTAssertEqual(CategoryIcons.icon(forCategoryNamed: "Десерты"), "heart.fill")
        XCTAssertEqual(CategoryIcons.icon(forCategoryNamed: "Напитки"), "drop.fill")
        XCTAssertEqual(CategoryIcons.icon(forCategoryNamed: "Неизвестно"), CategoryIcons.defaultIcon)
    }
}
