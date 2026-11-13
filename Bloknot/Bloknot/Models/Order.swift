import Foundation
import GRDB

/// Заказ на столе.
struct Order: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "orders"

    var id: UUID
    var tableId: Int64
    var status: OrderStatus
    var createdAt: Date
    var closedAt: Date?
    var guests: Int

    enum Columns {
        static let id = Column("id")
        static let tableId = Column("tableId")
        static let status = Column("status")
        static let createdAt = Column("createdAt")
        static let closedAt = Column("closedAt")
        static let guests = Column("guests")
    }

    init(
        id: UUID = UUID(),
        tableId: Int64,
        status: OrderStatus = .open,
        createdAt: Date = Date(),
        closedAt: Date? = nil,
        guests: Int = 2
    ) {
        self.id = id
        self.tableId = tableId
        self.status = status
        self.createdAt = createdAt
        self.closedAt = closedAt
        self.guests = guests
    }
}
