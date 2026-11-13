import Foundation
import XCTest
import GRDB
@testable import Bloknot

final class SeedDataTests: XCTestCase {
    func testTenCategoriesWithOneDishEach() throws {
        let db = try TestSupport.database()

        try db.read { db in
            let categories = try Category.order(Category.Columns.sortOrder).fetchAll(db)
            XCTAssertEqual(categories.count, 10, "в сиде ровно 10 категорий")

            let items = try MenuItem.fetchAll(db)
            XCTAssertEqual(items.count, 10, "в сиде ровно 10 блюд")

            for category in categories {
                let count = try MenuItem
                    .filter(Column("categoryId") == category.id)
                    .fetchCount(db)
                XCTAssertEqual(count, 1, "в категории «\(category.name)» должно быть одно блюдо")
            }
        }
    }

    func testExactSeedContent() throws {
        let db = try TestSupport.database()

        let expected: [(category: String, dish: String, price: Double)] = [
            ("Горячее", "Стейк Рибай", 1290),
            ("Салаты", "Цезарь с курицей", 590),
            ("Супы", "Борщ", 420),
            ("Десерты", "Чизкейк Нью-Йорк", 450),
            ("Напитки", "Эспрессо", 180),
            ("Закуски", "Брускетты с томатами", 380),
            ("Гарниры", "Картофель по-деревенски", 250),
            ("Соусы", "Тартар", 120),
            ("Вино", "Chianti Classico", 1890),
            ("Пиво", "Heineken 0.5", 350)
        ]

        for entry in expected {
            let found = try db.read { db -> MenuItem? in
                guard let category = try Category
                    .filter(Column("name") == entry.category)
                    .fetchOne(db) else {
                    return nil
                }
                return try MenuItem
                    .filter(Column("categoryId") == category.id)
                    .fetchOne(db)
            }

            let item = try XCTUnwrap(found, "нет категории или блюда: \(entry.category)")
            XCTAssertEqual(item.name, entry.dish)
            XCTAssertEqual(item.price, entry.price, accuracy: 0.001)
        }
    }

    func testTablesAreSeeded() throws {
        let db = try TestSupport.database()
        let tables = try db.read { try DiningTable.fetchAll($0) }
        XCTAssertEqual(tables.count, 12)
        XCTAssertEqual(Set(tables.map(\.zone)), ["Основной зал", "Терраса", "Бар"])
    }

    func testMigrationIsIdempotent() throws {
        let db = try TestSupport.database()
        try db.write { database in
            try SeedData.seed(database)
        }
        let categories = try db.read { try Category.fetchCount($0) }
        XCTAssertEqual(categories, 10, "повторный сид не должен дублировать данные")
    }
}
