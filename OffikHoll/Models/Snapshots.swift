import Foundation

struct MenuSnapshot: Equatable {
    var categories: [Category]
    var items: [MenuItem]

    static let empty = MenuSnapshot(categories: [], items: [])
}

/// Everything the floor screen needs about one table, computed in a single
/// database read. Views never query the database themselves.
struct FloorCard: Identifiable, Equatable {
    var table: RestaurantTable
    var order: Order?
    var previewLines: [String]
    var itemCount: Int
    var total: Double
    var guests: Int
    var openedAt: Date?

    var id: Int { table.id }
    var isOccupied: Bool { order != nil }
    var status: OrderStatus? { order?.status }
}

struct FloorStats: Equatable {
    var freeTables: Int
    var occupiedTables: Int
    var openOrders: Int
    var openTotal: Double
    var revenueToday: Double
    var guests: Int
    var paidOrdersToday: Int

    static let empty = FloorStats(
        freeTables: 0,
        occupiedTables: 0,
        openOrders: 0,
        openTotal: 0,
        revenueToday: 0,
        guests: 0,
        paidOrdersToday: 0
    )
}

struct FloorSnapshot: Equatable {
    var cards: [FloorCard]
    var stats: FloorStats

    static let empty = FloorSnapshot(cards: [], stats: .empty)
}

struct OrderLine: Identifiable, Equatable {
    var id: UUID
    var menuItemId: UUID
    var name: String
    var price: Double
    var quantity: Int
    var isSent: Bool

    var lineTotal: Double { price * Double(quantity) }
}

struct OrderSnapshot: Equatable {
    var order: Order?
    var table: RestaurantTable?
    var lines: [OrderLine]

    static let empty = OrderSnapshot(order: nil, table: nil, lines: [])
}
