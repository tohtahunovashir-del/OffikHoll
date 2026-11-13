import Foundation
import Combine
import XCTest
import GRDB
@testable import Bloknot

final class OrderFlowTests: XCTestCase {
    private func makeEnvironment() throws -> (DatabaseQueue, MenuRepository, OrderRepository, DiningTable) {
        let db = try TestSupport.database()
        let menuRepository = MenuRepository(database: db)
        let orderRepository = OrderRepository(database: db)
        let table = try XCTUnwrap(db.read { try DiningTable.order(Column("number")).fetchOne($0) })
        return (db, menuRepository, orderRepository, table)
    }

    func testAddIncrementSendPay() throws {
        let (db, menuRepository, orderRepository, table) = try makeEnvironment()
        let orderId = try orderRepository.openOrder(for: table)
        let dish = try XCTUnwrap(
            db.read { try MenuItem.filter(Column("name") == "Стейк Рибай").fetchOne($0) }
        )

        let viewModel = OrderViewModel(
            table: table,
            orderId: orderId,
            menuRepository: menuRepository,
            orderRepository: orderRepository
        )

        XCTAssertTrue(TestSupport.waitUntil { !viewModel.dishes.isEmpty }, "меню должно загрузиться")

        viewModel.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { viewModel.itemCount == 1 })
        XCTAssertEqual(viewModel.total, 1290, accuracy: 0.001)

        // Повторный тап увеличивает количество, а не создаёт вторую строку.
        viewModel.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { viewModel.itemCount == 2 })
        XCTAssertEqual(viewModel.lines.count, 1)
        XCTAssertEqual(viewModel.total, 2580, accuracy: 0.001)

        viewModel.sendToKitchen()
        XCTAssertTrue(TestSupport.waitUntil { viewModel.lines.allSatisfy(\.isSent) })
        XCTAssertFalse(viewModel.hasUnsent)

        viewModel.pay()
        XCTAssertTrue(TestSupport.waitUntil { viewModel.isClosed })

        let order = try db.read { try Order.fetchOne($0, key: orderId) }
        XCTAssertEqual(order?.status, OrderStatus.paid)
    }

    func testOpenOrderIsReused() throws {
        let (_, _, orderRepository, table) = try makeEnvironment()
        let first = try orderRepository.openOrder(for: table)
        let second = try orderRepository.openOrder(for: table)
        XCTAssertEqual(first, second, "повторное открытие стола возвращает тот же счёт")
    }

    func testPaidTableBecomesFree() throws {
        let (db, _, orderRepository, table) = try makeEnvironment()
        let orderId = try orderRepository.openOrder(for: table)
        let dish = try XCTUnwrap(db.read { try MenuItem.fetchOne($0) })
        try orderRepository.add(menuItem: dish, to: orderId)
        try orderRepository.markPaid(orderId: orderId)

        let summaries = TableRepository(database: db)
        var latest: [TableSummary] = []
        let cancellable = summaries.observeSummaries().sink(
            receiveCompletion: { _ in },
            receiveValue: { latest = $0 }
        )
        defer { cancellable.cancel() }

        XCTAssertTrue(TestSupport.waitUntil {
            guard let summary = latest.first(where: { $0.table.id == table.id }) else { return false }
            return summary.status == .free && summary.orderId == nil
        }, "после оплаты стол должен стать свободным")
    }

    func testDecrementToZeroRemovesLine() throws {
        let (db, menuRepository, orderRepository, table) = try makeEnvironment()
        let orderId = try orderRepository.openOrder(for: table)
        let dish = try XCTUnwrap(db.read { try MenuItem.fetchOne($0) })

        let viewModel = OrderViewModel(
            table: table,
            orderId: orderId,
            menuRepository: menuRepository,
            orderRepository: orderRepository
        )
        XCTAssertTrue(TestSupport.waitUntil { !viewModel.dishes.isEmpty })

        viewModel.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { viewModel.itemCount == 1 })

        let line = try XCTUnwrap(viewModel.lines.first)
        viewModel.decrement(line)
        XCTAssertTrue(TestSupport.waitUntil { viewModel.lines.isEmpty })
    }

    func testCancelOrderRemovesBill() throws {
        let (db, _, orderRepository, table) = try makeEnvironment()
        let orderId = try orderRepository.openOrder(for: table)
        try orderRepository.cancelOrder(orderId: orderId)
        let order = try db.read { try Order.fetchOne($0, key: orderId) }
        XCTAssertNil(order)
    }
}
