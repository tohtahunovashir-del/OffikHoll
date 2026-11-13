import Foundation
import GRDB

/// Позиция заказа. Название и цена фиксируются снимком: если блюдо поменяют
/// в меню, уже открытый счёт не изменится.
struct OrderItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "order_items"

    var id: UUID
    var orderId: UUID
    var menuItemId: UUID
    var name: String
    var price: Double
    var quantity: Int
    var isSent: Bool
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let orderId = Column("orderId")
        static let menuItemId = Column("menuItemId")
        static let name = Column("name")
        static let price = Column("price")
        static let quantity = Column("quantity")
        static let isSent = Column("isSent")
        static let createdAt = Column("createdAt")
    }

    init(
        id: UUID = UUID(),
        orderId: UUID,
        menuItemId: UUID,
        name: String,
        price: Double,
        quantity: Int = 1,
        isSent: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.orderId = orderId
        self.menuItemId = menuItemId
        self.name = name
        self.price = price
        self.quantity = quantity
        self.isSent = isSent
        self.createdAt = createdAt
    }

    var total: Double { price * Double(quantity) }
}
