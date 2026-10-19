import Foundation
import GRDB

/// Menu category. Plain value type (struct) so SwiftUI diffing is cheap and
/// GRDB's value observation can replace the whole array reactively.
struct Category: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "categories"

    var id: UUID
    var name: String
    /// Display order in the category rail.
    var order: Int
    var icon: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case order = "sortOrder"
    }

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let sortOrder = Column("sortOrder")
    }

    init(id: UUID = UUID(), name: String, order: Int, icon: String = CategoryIcons.defaultIcon) {
        self.id = id
        self.name = name
        self.order = order
        self.icon = icon
    }
}
