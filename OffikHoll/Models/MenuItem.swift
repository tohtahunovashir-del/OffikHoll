import Foundation
import GRDB

struct MenuItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "menu_items"

    var id: UUID
    var name: String
    var price: Double
    var categoryId: UUID
    /// Portion / composition / short description.
    var details: String
    var isAvailable: Bool
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let price = Column("price")
        static let categoryId = Column("categoryId")
        static let isAvailable = Column("isAvailable")
        static let createdAt = Column("createdAt")
    }

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        categoryId: UUID,
        details: String = "",
        isAvailable: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.categoryId = categoryId
        self.details = details
        self.isAvailable = isAvailable
        self.createdAt = createdAt
    }

    var searchableText: String {
        "\(name) \(details)".lowercased()
    }
}
