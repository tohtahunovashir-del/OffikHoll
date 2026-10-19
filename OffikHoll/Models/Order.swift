import Foundation
import GRDB

enum OrderStatus: String, Codable, DatabaseValueConvertible, Hashable {
    case active
    case sent
    case paid
}

struct Order: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "orders"

    var id: UUID
    var tableId: Int
    var status: OrderStatus
    var totalAmount: Double
    var createdAt: Date
    var sentAt: Date?
    var closedAt: Date?
    var guests: Int
    var note: String
    var paymentMethod: String?

    enum Columns {
        static let id = Column("id")
        static let tableId = Column("tableId")
        static let status = Column("status")
        static let totalAmount = Column("totalAmount")
        static let createdAt = Column("createdAt")
        static let closedAt = Column("closedAt")
    }

    init(
        id: UUID = UUID(),
        tableId: Int,
        status: OrderStatus = .active,
        totalAmount: Double = 0,
        createdAt: Date = Date(),
        sentAt: Date? = nil,
        closedAt: Date? = nil,
        guests: Int = 2,
        note: String = "",
        paymentMethod: String? = nil
    ) {
        self.id = id
        self.tableId = tableId
        self.status = status
        self.totalAmount = totalAmount
        self.createdAt = createdAt
        self.sentAt = sentAt
        self.closedAt = closedAt
        self.guests = guests
        self.note = note
        self.paymentMethod = paymentMethod
    }

    var isOpen: Bool { status != .paid }
}
