import Foundation
import GRDB

enum TableStatus: String, Codable, DatabaseValueConvertible, Hashable {
    case free
    case occupied
}

/// Named `RestaurantTable` on purpose: SwiftUI declares a `Table` type, so the
/// shorter name would clash in every view file.
struct RestaurantTable: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "tables"

    var id: Int
    var number: Int
    var status: TableStatus
    var currentOrderId: UUID?
    var zone: String
    var seats: Int

    enum Columns {
        static let id = Column("id")
        static let number = Column("number")
        static let status = Column("status")
        static let zone = Column("zone")
    }

    init(
        id: Int,
        number: Int,
        status: TableStatus = .free,
        currentOrderId: UUID? = nil,
        zone: String = "Основной зал",
        seats: Int = 2
    ) {
        self.id = id
        self.number = number
        self.status = status
        self.currentOrderId = currentOrderId
        self.zone = zone
        self.seats = seats
    }
}
