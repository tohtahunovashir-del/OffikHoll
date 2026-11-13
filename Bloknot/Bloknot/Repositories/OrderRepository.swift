import Combine
import Foundation
import GRDB

struct OrderSnapshot: Equatable {
    var order: Order?
    var lines: [OrderItem]

    var total: Double {
        lines.reduce(0) { $0 + $1.total }
    }

    var itemCount: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    var hasUnsent: Bool {
        lines.contains { !$0.isSent }
    }

    static let empty = OrderSnapshot(order: nil, lines: [])
}

final class OrderRepository {
    private let database: DatabaseQueue

    init(database: DatabaseQueue) {
        self.database = database
    }

    // MARK: - Opening

    /// Возвращает открытый счёт на столе или создаёт новый.
    func openOrder(for table: DiningTable) throws -> UUID {
        try database.write { db in
            let existing = try Order
                .filter(Column("tableId") == table.id)
                .filter(Column("status") != OrderStatus.paid.rawValue)
                .order(Column("createdAt").desc)
                .fetchOne(db)

            if let existing = existing {
                return existing.id
            }

            let order = Order(tableId: table.id)
            try order.insert(db)
            return order.id
        }
    }

    // MARK: - Observation

    func observeOrder(id: UUID) -> AnyPublisher<OrderSnapshot, Error> {
        ValueObservation
            .tracking { db in
                OrderSnapshot(
                    order: try Order.fetchOne(db, key: id),
                    lines: try OrderItem
                        .filter(Column("orderId") == id)
                        .order(Column("createdAt"))
                        .fetchAll(db)
                )
            }
            .publisher(in: database)
            .eraseToAnyPublisher()
    }

    // MARK: - Mutations

    func add(menuItem: MenuItem, to orderId: UUID) throws {
        try database.write { db in
            let unsent = try OrderItem
                .filter(Column("orderId") == orderId)
                .filter(Column("menuItemId") == menuItem.id)
                .filter(Column("isSent") == false)
                .fetchOne(db)

            if var line = unsent {
                line.quantity += 1
                try line.update(db)
            } else {
                let line = OrderItem(
                    orderId: orderId,
                    menuItemId: menuItem.id,
                    name: menuItem.name,
                    price: menuItem.price
                )
                try line.insert(db)
            }

            try Self.setStatus(.open, orderId: orderId, in: db)
        }
    }

    func setQuantity(lineId: UUID, quantity: Int) throws {
        try database.write { db in
            guard var line = try OrderItem.fetchOne(db, key: lineId) else { return }
            if quantity <= 0 {
                _ = try OrderItem.deleteOne(db, key: lineId)
            } else {
                line.quantity = min(quantity, 99)
                try line.update(db)
            }
            try Self.setStatus(.open, orderId: line.orderId, in: db)
        }
    }

    func removeLine(id: UUID) throws {
        try database.write { db in
            _ = try OrderItem.deleteOne(db, key: id)
        }
    }

    func sendToKitchen(orderId: UUID) throws {
        try database.write { db in
            let lines = try OrderItem
                .filter(Column("orderId") == orderId)
                .fetchAll(db)

            for var line in lines where !line.isSent {
                line.isSent = true
                try line.update(db)
            }

            try Self.setStatus(.sent, orderId: orderId, in: db)
        }
    }

    func markPaid(orderId: UUID) throws {
        try database.write { db in
            guard var order = try Order.fetchOne(db, key: orderId) else { return }
            order.status = .paid
            order.closedAt = Date()
            try order.update(db)

            let lines = try OrderItem
                .filter(Column("orderId") == orderId)
                .fetchAll(db)
            for var line in lines where !line.isSent {
                line.isSent = true
                try line.update(db)
            }
        }
    }

    /// Закрытие без оплаты — счёт удаляется, стол освобождается.
    func cancelOrder(orderId: UUID) throws {
        try database.write { db in
            _ = try Order.deleteOne(db, key: orderId)
        }
    }

    // MARK: - Helpers

    private static func setStatus(_ status: OrderStatus, orderId: UUID, in db: Database) throws {
        guard var order = try Order.fetchOne(db, key: orderId) else { return }
        guard order.status != .paid else { return }
        order.status = status
        try order.update(db)
    }
}
