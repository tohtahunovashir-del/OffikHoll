import Foundation
import GRDB

enum TableStatus: String, Codable, CaseIterable {
    case free = "Свободен"
    case occupied = "Занят"
}

enum OrderStatus: String, Codable, CaseIterable {
    case active = "Активен"
    case sent = "На кухне"
    case paid = "Оплачен"
}

struct Category: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "categories"
    var id: UUID
    var name: String
    var order: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case order = "sortOrder"
    }
}

struct MenuItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "menuItems"
    var id: UUID
    var name: String
    var price: Double
    var categoryId: UUID
}

struct DiningTable: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "diningTables"
    var id: Int
    var number: Int
    var status: TableStatus
    var currentOrderId: UUID?
}

struct Order: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "orders"
    var id: UUID
    var tableId: Int
    var status: OrderStatus
    var totalAmount: Double
    var createdAt: Date
}

struct OrderItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "orderItems"
    var id: UUID
    var orderId: UUID
    var menuItemId: UUID
    var quantity: Int
    // Снимок названия и цены сохраняет корректный чек, даже если меню изменится.
    var itemName: String
    var unitPrice: Double
}

struct ParsedMenuItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var price: Double
    var category: String
    var isSelected = true
}
