import Foundation
import GRDB

/// Стартовое наполнение: ровно 10 категорий, по одному блюду в каждой.
/// Это проверочный набор — своё меню официант добавляет сам.
enum SeedData {
    struct SeedCategory {
        let name: String
        let item: SeedItem
    }

    struct SeedItem {
        let name: String
        let price: Double
    }

    struct SeedTable {
        let number: Int
        let zone: String
        let seats: Int
    }

    static let categories: [SeedCategory] = [
        SeedCategory(name: "Горячее", item: SeedItem(name: "Стейк Рибай", price: 1290)),
        SeedCategory(name: "Салаты", item: SeedItem(name: "Цезарь с курицей", price: 590)),
        SeedCategory(name: "Супы", item: SeedItem(name: "Борщ", price: 420)),
        SeedCategory(name: "Десерты", item: SeedItem(name: "Чизкейк Нью-Йорк", price: 450)),
        SeedCategory(name: "Напитки", item: SeedItem(name: "Эспрессо", price: 180)),
        SeedCategory(name: "Закуски", item: SeedItem(name: "Брускетты с томатами", price: 380)),
        SeedCategory(name: "Гарниры", item: SeedItem(name: "Картофель по-деревенски", price: 250)),
        SeedCategory(name: "Соусы", item: SeedItem(name: "Тартар", price: 120)),
        SeedCategory(name: "Вино", item: SeedItem(name: "Chianti Classico", price: 1890)),
        SeedCategory(name: "Пиво", item: SeedItem(name: "Heineken 0.5", price: 350))
    ]

    static let tables: [SeedTable] = [
        SeedTable(number: 1, zone: "Основной зал", seats: 2),
        SeedTable(number: 2, zone: "Основной зал", seats: 4),
        SeedTable(number: 3, zone: "Основной зал", seats: 2),
        SeedTable(number: 4, zone: "Основной зал", seats: 6),
        SeedTable(number: 5, zone: "Основной зал", seats: 4),
        SeedTable(number: 6, zone: "Основной зал", seats: 2),
        SeedTable(number: 7, zone: "Терраса", seats: 4),
        SeedTable(number: 8, zone: "Терраса", seats: 4),
        SeedTable(number: 9, zone: "Терраса", seats: 2),
        SeedTable(number: 10, zone: "Терраса", seats: 6),
        SeedTable(number: 11, zone: "Бар", seats: 2),
        SeedTable(number: 12, zone: "Бар", seats: 2)
    ]

    /// Идемпотентно: если данные уже есть, повторно не вставляет.
    static func seed(_ db: Database) throws {
        if try Category.fetchCount(db) == 0 {
            let now = Date()
            for (index, seedCategory) in categories.enumerated() {
                let category = Category(name: seedCategory.name, sortOrder: index, createdAt: now)
                try category.insert(db)
                let item = MenuItem(
                    categoryId: category.id,
                    name: seedCategory.item.name,
                    price: seedCategory.item.price,
                    createdAt: now
                )
                try item.insert(db)
            }
        }

        if try DiningTable.fetchCount(db) == 0 {
            for seedTable in tables {
                let table = DiningTable(number: seedTable.number, zone: seedTable.zone, seats: seedTable.seats)
                try table.insert(db)
            }
        }
    }
}
