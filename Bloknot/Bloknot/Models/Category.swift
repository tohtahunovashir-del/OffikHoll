import Foundation
import GRDB

/// Категория меню. Только struct: GRDB-запись и значение для SwiftUI-диффинга.
struct Category: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "categories"

    var id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let sortOrder = Column("sortOrder")
        static let createdAt = Column("createdAt")
    }

    init(id: UUID = UUID(), name: String, sortOrder: Int, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
