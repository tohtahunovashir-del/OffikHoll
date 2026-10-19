import Foundation
import GRDB
import Combine

/// Per-bill store. Created once per opened order and disposed when the order
/// screen goes away. All mutations are transactional; the UI is driven by a
/// single observation of the order, its table and its lines.
final class OrderStore: ObservableObject {
    @Published private(set) var order: Order?
    @Published private(set) var table: RestaurantTable?
    @Published private(set) var lines: [OrderLine] = []
    @Published private(set) var isLoading = true
    @Published private(set) var didClose = false
    @Published var errorMessage: String?

    let orderId: UUID
    private let database: DatabaseQueue
    private var observationCancellable: AnyCancellable?

    init(database: DatabaseQueue, orderId: UUID) {
        self.database = database
        self.orderId = orderId
        observe()
    }

    private func observe() {
        let id = orderId
        ValueObservation
            .tracking { db -> OrderSnapshot in
                let order = try Order.fetchOne(db, key: id)
                let table: RestaurantTable?
                if let order {
                    table = try RestaurantTable.fetchOne(db, key: order.tableId)
                } else {
                    table = nil
                }
                let rows = try Row.fetchAll(db, sql: """
                    SELECT id AS id,
                           menuItemId AS menuItemId,
                           COALESCE(NULLIF(nameSnapshot, ''), 'Блюдо') AS name,
                           priceSnapshot AS price,
                           quantity AS quantity,
                           isSent AS isSent
                    FROM order_items
                    WHERE orderId = ?
                    ORDER BY createdAt ASC, rowid ASC
                    """, arguments: [id])
                let lines = rows.map { row -> OrderLine in
                    let lineId: UUID = row["id"]
                    let menuItemId: UUID = row["menuItemId"]
                    let name: String = row["name"]
                    let price: Double = row["price"]
                    let quantity: Int = row["quantity"]
                    let isSent: Bool = row["isSent"]
                    return OrderLine(
                        id: lineId,
                        menuItemId: menuItemId,
                        name: name,
                        price: price,
                        quantity: quantity,
                        isSent: isSent
                    )
                }
                return OrderSnapshot(order: order, table: table, lines: lines)
            }
            .publisher(in: database)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось загрузить заказ: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] snapshot in
                self?.order = snapshot.order
                self?.table = snapshot.table
                self?.lines = snapshot.lines
                self?.isLoading = false
            })
            .store(in: &observationCancellable)
    }

    // MARK: - Derived values

    var total: Double {
        lines.reduce(0) { $0 + $1.lineTotal }
    }

    var itemCount: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }

    var unsentCount: Int {
        lines.filter { !$0.isSent }.reduce(0) { $0 + $1.quantity }
    }

    var hasUnsentItems: Bool { unsentCount > 0 }

    var guests: Int { order?.guests ?? 2 }

    var tableNumber: Int { table?.number ?? 0 }

    var status: OrderStatus { order?.status ?? .active }

    var isPaid: Bool { order?.status == .paid }

    var paymentMethodTitle: String? {
        guard let raw = order?.paymentMethod,
              let method = PaymentMethod(rawValue: raw) else { return nil }
        return method.title
    }

    var note: String { order?.note ?? "" }

    func quantity(for menuItemId: UUID) -> Int {
        lines.filter { $0.menuItemId == menuItemId }.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Line mutations

    func add(_ item: MenuItem) {
        guard !isPaid else {
            errorMessage = "Оплаченный заказ нельзя изменить."
            return
        }
        do {
            try database.write { db in
                if let existing = try OrderItem
                    .filter(OrderItem.Columns.orderId == orderId)
                    .filter(OrderItem.Columns.menuItemId == item.id)
                    .filter(OrderItem.Columns.isSent == false)
                    .order(OrderItem.Columns.createdAt.desc)
                    .fetchOne(db) {
                    try db.execute(
                        sql: "UPDATE order_items SET quantity = quantity + 1 WHERE id = ?",
                        arguments: [existing.id]
                    )
                } else {
                    let line = OrderItem(
                        orderId: orderId,
                        menuItemId: item.id,
                        quantity: 1,
                        nameSnapshot: item.name,
                        priceSnapshot: item.price
                    )
                    try line.insert(db)
                }
                try Self.recalculateTotal(db, orderId: orderId)
            }
        } catch {
            errorMessage = "Не удалось добавить блюдо: \(error.localizedDescription)"
        }
    }

    func increment(lineId: UUID) {
        guard !isPaid else { return }
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE order_items SET quantity = quantity + 1 WHERE id = ? AND orderId = ?",
                    arguments: [lineId, orderId]
                )
                try Self.recalculateTotal(db, orderId: orderId)
            }
        } catch {
            errorMessage = "Не удалось изменить количество: \(error.localizedDescription)"
        }
    }

    func decrement(lineId: UUID) {
        guard !isPaid else { return }
        do {
            try database.write { db in
                let quantity = try Int.fetchOne(
                    db,
                    sql: "SELECT quantity FROM order_items WHERE id = ? AND orderId = ?",
                    arguments: [lineId, orderId]
                ) ?? 0
                if quantity <= 1 {
                    try db.execute(
                        sql: "DELETE FROM order_items WHERE id = ? AND orderId = ?",
                        arguments: [lineId, orderId]
                    )
                } else {
                    try db.execute(
                        sql: "UPDATE order_items SET quantity = quantity - 1 WHERE id = ? AND orderId = ?",
                        arguments: [lineId, orderId]
                    )
                }
                try Self.recalculateTotal(db, orderId: orderId)
            }
        } catch {
            errorMessage = "Не удалось изменить количество: \(error.localizedDescription)"
        }
    }

    func remove(lineId: UUID) {
        guard !isPaid else { return }
        do {
            try database.write { db in
                try db.execute(
                    sql: "DELETE FROM order_items WHERE id = ? AND orderId = ?",
                    arguments: [lineId, orderId]
                )
                try Self.recalculateTotal(db, orderId: orderId)
            }
        } catch {
            errorMessage = "Не удалось удалить позицию: \(error.localizedDescription)"
        }
    }

    func updateGuests(_ guests: Int) {
        let clamped = max(1, min(guests, 30))
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE orders SET guests = ? WHERE id = ?",
                    arguments: [clamped, orderId]
                )
            }
        } catch {
            errorMessage = "Не удалось изменить число гостей: \(error.localizedDescription)"
        }
    }

    func updateNote(_ note: String) {
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE orders SET note = ? WHERE id = ?",
                    arguments: [note.trimmingCharacters(in: .whitespacesAndNewlines), orderId]
                )
            }
        } catch {
            errorMessage = "Не удалось сохранить комментарий: \(error.localizedDescription)"
        }
    }

    // MARK: - Kitchen / payment / closing

    @discardableResult
    func sendToKitchen() -> Bool {
        guard !isPaid else { return false }
        guard lines.contains(where: { !$0.isSent }) else {
            errorMessage = "Все позиции уже отправлены на кухню."
            return false
        }
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE order_items SET isSent = 1 WHERE orderId = ? AND isSent = 0",
                    arguments: [orderId]
                )
                try db.execute(
                    sql: "UPDATE orders SET status = ?, sentAt = COALESCE(sentAt, ?) WHERE id = ?",
                    arguments: [OrderStatus.sent.rawValue, Date(), orderId]
                )
            }
            return true
        } catch {
            errorMessage = "Не удалось отправить заказ на кухню: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func pay(method: PaymentMethod) -> Bool {
        guard let order else {
            errorMessage = "Заказ не найден."
            return false
        }
        guard !lines.isEmpty else {
            errorMessage = "В заказе нет блюд."
            return false
        }
        guard order.status != .paid else { return false }
        do {
            try database.write { db in
                let total = try Self.computeTotal(db, orderId: orderId)
                try db.execute(
                    sql: "UPDATE order_items SET isSent = 1 WHERE orderId = ? AND isSent = 0",
                    arguments: [orderId]
                )
                try db.execute(
                    sql: "UPDATE orders SET status = ?, totalAmount = ?, closedAt = ?, paymentMethod = ? WHERE id = ?",
                    arguments: [OrderStatus.paid.rawValue, total, Date(), method.rawValue, orderId]
                )
                try db.execute(
                    sql: "UPDATE tables SET status = ?, currentOrderId = NULL WHERE id = ?",
                    arguments: [TableStatus.free.rawValue, order.tableId]
                )
            }
            didClose = true
            return true
        } catch {
            errorMessage = "Не удалось провести оплату: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func cancelOrder() -> Bool {
        guard let order else { return false }
        guard order.status != .paid else {
            errorMessage = "Оплаченный заказ нельзя отменить."
            return false
        }
        do {
            try database.write { db in
                try db.execute(
                    sql: "DELETE FROM orders WHERE id = ?",
                    arguments: [orderId]
                )
                try db.execute(
                    sql: "UPDATE tables SET status = ?, currentOrderId = NULL WHERE id = ?",
                    arguments: [TableStatus.free.rawValue, order.tableId]
                )
            }
            didClose = true
            return true
        } catch {
            errorMessage = "Не удалось закрыть заказ: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Helpers

    private static func computeTotal(_ db: Database, orderId: UUID) throws -> Double {
        try Double.fetchOne(
            db,
            sql: "SELECT COALESCE(SUM(priceSnapshot * quantity), 0) FROM order_items WHERE orderId = ?",
            arguments: [orderId]
        ) ?? 0
    }

    private static func recalculateTotal(_ db: Database, orderId: UUID) throws {
        let total = try computeTotal(db, orderId: orderId)
        try db.execute(
            sql: "UPDATE orders SET totalAmount = ? WHERE id = ?",
            arguments: [total, orderId]
        )
    }
}
