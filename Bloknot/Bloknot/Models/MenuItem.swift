import Foundation
import GRDB

/// Блюдо меню.
struct MenuItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "menu_items"

    var id: UUID
    var categoryId: UUID
    var name: String
    var price: Double
    var isAvailable: Bool
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let categoryId = Column("categoryId")
        static let name = Column("name")
        static let price = Column("price")
        static let isAvailable = Column("isAvailable")
        static let createdAt = Column("createdAt")
    }

    init(
        id: UUID = UUID(),
        categoryId: UUID,
        name: String,
        price: Double,
        isAvailable: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
        self.price = price
        self.isAvailable = isAvailable
        self.createdAt = createdAt
    }
}
