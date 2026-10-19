import Foundation
import GRDB

/// Order line. Name and price are snapshotted at the moment the guest orders
/// the dish, so later edits to the menu never rewrite historical orders and
/// deleting a menu item cannot break an open bill.
struct OrderItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "order_items"

    var id: UUID
    var orderId: UUID
    var menuItemId: UUID
    var quantity: Int
    var nameSnapshot: String
    var priceSnapshot: Double
    var isSent: Bool
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let orderId = Column("orderId")
        static let menuItemId = Column("menuItemId")
        static let isSent = Column("isSent")
        static let createdAt = Column("createdAt")
    }

    init(
        id: UUID = UUID(),
        orderId: UUID,
        menuItemId: UUID,
        quantity: Int = 1,
        nameSnapshot: String,
        priceSnapshot: Double,
        isSent: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.orderId = orderId
        self.menuItemId = menuItemId
        self.quantity = quantity
        self.nameSnapshot = nameSnapshot
        self.priceSnapshot = priceSnapshot
        self.isSent = isSent
        self.createdAt = createdAt
    }
}
