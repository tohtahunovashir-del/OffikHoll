import Combine
import Foundation
import GRDB

struct MenuCatalog: Equatable {
    var categories: [Category]
    var items: [MenuItem]

    static let empty = MenuCatalog(categories: [], items: [])
}

/// Чтение и запись меню. Никакого кеша: источник истины — GRDB.
final class MenuRepository {
    private let database: DatabaseQueue

    init(database: DatabaseQueue) {
        self.database = database
    }

    // MARK: - Observation

    func observeCatalog() -> AnyPublisher<MenuCatalog, Error> {
        ValueObservation
            .tracking { db in
                MenuCatalog(
                    categories: try Category
                        .order(Category.Columns.sortOrder, Category.Columns.name)
                        .fetchAll(db),
                    items: try MenuItem
                        .order(MenuItem.Columns.name)
                        .fetchAll(db)
                )
            }
            .publisher(in: database)
            .eraseToAnyPublisher()
    }

    // MARK: - Categories

    @discardableResult
    func addCategory(named name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            throw MenuError.invalidName
        }

        return try database.write { db in
            if let existing = try Category.fetchAll(db).first(where: {
                Self.normalized($0.name) == Self.normalized(trimmed)
            }) {
                return existing.id
            }
            let nextOrder = (try Int.fetchOne(db, sql: "SELECT MAX(sortOrder) FROM categories") ?? -1) + 1
            let category = Category(name: trimmed, sortOrder: nextOrder)
            try category.insert(db)
            return category.id
        }
    }

    func deleteCategory(id: UUID) throws {
        try database.write { db in
            _ = try Category.deleteOne(db, key: id)
        }
    }

    // MARK: - Items

    @discardableResult
    func addItem(name: String, price: Double, categoryId: UUID) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw MenuError.invalidName }
        guard price >= Constants.ocrMinimumPrice, price <= Constants.ocrMaximumPrice else {
            throw MenuError.invalidPrice
        }

        return try database.write { db in
            let item = MenuItem(categoryId: categoryId, name: trimmed, price: price)
            try item.insert(db)
            return item.id
        }
    }

    func updateItem(id: UUID, name: String, price: Double, categoryId: UUID) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw MenuError.invalidName }
        guard price >= Constants.ocrMinimumPrice, price <= Constants.ocrMaximumPrice else {
            throw MenuError.invalidPrice
        }

        try database.write { db in
            guard var item = try MenuItem.fetchOne(db, key: id) else { return }
            item.name = trimmed
            item.price = price
            item.categoryId = categoryId
            try item.update(db)
        }
    }

    func deleteItem(id: UUID) throws {
        try database.write { db in
            _ = try MenuItem.deleteOne(db, key: id)
        }
    }

    /// Импорт распознанных блюд. Категории создаются по мере необходимости,
    /// дубликаты внутри одной категории пропускаются.
    @discardableResult
    func importDishes(_ dishes: [ParsedDish]) throws -> Int {
        guard !dishes.isEmpty else { return 0 }

        return try database.write { db in
            var categories = try Category.order(Category.Columns.sortOrder).fetchAll(db)
            var existingKeys = Set(
                try MenuItem.fetchAll(db).map { Self.itemKey(categoryId: $0.categoryId, name: $0.name) }
            )
            var inserted = 0

            for dish in dishes {
                let categoryName = dish.category.trimmingCharacters(in: .whitespacesAndNewlines)
                let safeCategoryName = categoryName.isEmpty ? Constants.defaultCategoryName : categoryName

                let category: Category
                if let found = categories.first(where: {
                    Self.normalized($0.name) == Self.normalized(safeCategoryName)
                }) {
                    category = found
                } else {
                    let nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
                    let created = Category(name: safeCategoryName, sortOrder: nextOrder)
                    try created.insert(db)
                    categories.append(created)
                    category = created
                }

                let key = Self.itemKey(categoryId: category.id, name: dish.name)
                guard !existingKeys.contains(key) else { continue }

                let item = MenuItem(
                    categoryId: category.id,
                    name: dish.name,
                    price: dish.price
                )
                try item.insert(db)
                existingKeys.insert(key)
                inserted += 1
            }

            return inserted
        }
    }

    // MARK: - Vocabulary

    /// Словарь для Vision: названия категорий и блюд, чтобы OCR узнавал
    /// знакомые слова с большей вероятностью.
    func vocabulary() throws -> [String] {
        try database.read { db in
            let categories = try Category.fetchAll(db).map(\.name)
            let items = try MenuItem.fetchAll(db).map(\.name)
            return categories + items
        }
    }

    func categoryNames() throws -> [String] {
        try database.read { db in
            try Category.order(Category.Columns.sortOrder).fetchAll(db).map(\.name)
        }
    }

    // MARK: - Helpers

    static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func itemKey(categoryId: UUID, name: String) -> String {
        categoryId.uuidString + "|" + normalized(name)
    }
}

enum MenuError: LocalizedError {
    case invalidName
    case invalidPrice

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Название должно содержать минимум 2 символа."
        case .invalidPrice:
            return "Цена должна быть от \(Int(Constants.ocrMinimumPrice)) до \(Int(Constants.ocrMaximumPrice)) ₽."
        }
    }
}
