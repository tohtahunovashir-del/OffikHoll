import Foundation
import XCTest
import GRDB
@testable import Bloknot

final class MenuRepositoryTests: XCTestCase {
    func testImportCreatesCategoryAndSkipsDuplicates() throws {
        let db = try TestSupport.database()
        let repository = MenuRepository(database: db)

        let dishes = [
            ParsedDish(name: "Круассан", price: 280, category: "Выпечка", confidence: 0.9),
            ParsedDish(name: "Круассан", price: 280, category: "Выпечка", confidence: 0.9)
        ]

        let inserted = try repository.importDishes(dishes)
        XCTAssertEqual(inserted, 1)

        let category = try db.read {
            try Category.filter(Column("name") == "Выпечка").fetchOne($0)
        }
        XCTAssertNotNil(category)

        let repeated = try repository.importDishes(dishes)
        XCTAssertEqual(repeated, 0, "повторный импорт не дублирует блюда")
    }

    func testImportMatchesExistingCategoryCaseInsensitively() throws {
        let db = try TestSupport.database()
        let repository = MenuRepository(database: db)
        let before = try db.read { try Category.fetchCount($0) }

        _ = try repository.importDishes([
            ParsedDish(name: "Новый салат", price: 500, category: "салаты", confidence: 0.8)
        ])

        let after = try db.read { try Category.fetchCount($0) }
        XCTAssertEqual(before, after, "категория должна найтись без учёта регистра")
    }

    func testAddItemValidation() throws {
        let db = try TestSupport.database()
        let repository = MenuRepository(database: db)
        let category = try XCTUnwrap(db.read { try Category.fetchOne($0) })

        XCTAssertThrowsError(try repository.addItem(name: "A", price: 100, categoryId: category.id))
        XCTAssertThrowsError(try repository.addItem(name: "Суп", price: 0, categoryId: category.id))
        XCTAssertNoThrow(try repository.addItem(name: "Суп", price: 300, categoryId: category.id))
    }

    func testVocabularyContainsSeedNames() throws {
        let db = try TestSupport.database()
        let repository = MenuRepository(database: db)
        let vocabulary = try repository.vocabulary()

        XCTAssertTrue(vocabulary.contains("Салаты"))
        XCTAssertTrue(vocabulary.contains("Цезарь с курицей"))
        XCTAssertEqual(Set(vocabulary).count, vocabulary.count)
    }

    func testCategoryNamesAreOrdered() throws {
        let db = try TestSupport.database()
        let repository = MenuRepository(database: db)
        XCTAssertEqual(try repository.categoryNames().first, "Горячее")
    }
}
