import XCTest
import GRDB
@testable import OffikHoll

/// End-to-end checks of the waiter's actual shift: open a table, add dishes,
/// send them to the kitchen, pay and free the table. These exercise the real
/// GRDB schema, the reactive stores and the money math at runtime.
final class StoreFlowTests: XCTestCase {

    // MARK: - Menu store

    func testMenuStoreLoadsSeedAndImportsScannedDishes() throws {
        let db = try TestSupport.makeDatabase()
        let store = MenuStore(database: db)

        XCTAssertTrue(TestSupport.waitUntil { !store.categories.isEmpty }, "ValueObservation должен наполнить меню")
        XCTAssertFalse(store.items.isEmpty)

        let drafts = [
            MenuItemDraft(name: "Тестовое блюдо", price: 500, categoryName: "Салаты"),
            MenuItemDraft(name: "Блюдо из новой категории", price: 700, categoryName: "Сезонное")
        ]
        let first = try XCTUnwrap(store.importMenuItems(drafts))
        XCTAssertEqual(first.inserted, 2)
        XCTAssertEqual(first.createdCategories, 1)
        XCTAssertEqual(first.skipped, 0)

        // Same drafts again: everything is a duplicate now.
        let second = try XCTUnwrap(store.importMenuItems(drafts))
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.skipped, 2)
        XCTAssertEqual(second.createdCategories, 0)

        let stored = try db.read { db in
            try MenuItem.filter(Column("name") == "Тестовое блюдо").fetchCount(db)
        }
        XCTAssertEqual(stored, 1, "дубликаты не должны попадать в базу")
    }

    func testMenuStoreRejectsInvalidDrafts() throws {
        let db = try TestSupport.makeDatabase()
        let store = MenuStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !store.categories.isEmpty })

        XCTAssertNil(store.importMenuItems([]))
        XCTAssertNotNil(store.errorMessage)

        let result = try XCTUnwrap(
            store.importMenuItems([MenuItemDraft(name: "A", price: 0, categoryName: "Разное")])
        )
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.skipped, 1)
    }

    func testMenuItemAvailabilityToggle() throws {
        let db = try TestSupport.makeDatabase()
        let store = MenuStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !store.items.isEmpty })

        let item = try XCTUnwrap(store.items.first)
        store.toggleAvailability(item)

        let updated = try db.read { try MenuItem.fetchOne(db, key: item.id) }
        XCTAssertTrue(updated?.isAvailable == !item.isAvailable)

        let inStock = store.availableItems.count
        XCTAssertEqual(inStock, store.items.filter(\.isAvailable).count)
    }

    // MARK: - Floor store

    func testFloorOpensAndReusesTheSameBill() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 1 }))

        let first = try XCTUnwrap(floor.openOrder(for: table))
        let second = try XCTUnwrap(floor.openOrder(for: table))
        XCTAssertEqual(first, second, "повторный тап по столу открывает тот же счёт")

        let updated = try db.read { try RestaurantTable.fetchOne(db, key: table.id) }
        XCTAssertEqual(updated?.status, TableStatus.occupied)
        XCTAssertEqual(updated?.currentOrderId, first)

        XCTAssertTrue(TestSupport.waitUntil { floor.stats.openOrders == 1 })
        XCTAssertEqual(floor.stats.occupiedTables, 1)
    }

    func testTableNumberMustBeUnique() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        XCTAssertNil(floor.addTable(number: 42, seats: 4, zone: "Терраса"))
        XCTAssertTrue(
            TestSupport.waitUntil { floor.cards.contains(where: { $0.table.number == 42 }) },
            "новый стол должен появиться на карте зала"
        )

        let duplicate = floor.addTable(number: 42, seats: 2, zone: "Бар")
        XCTAssertEqual(duplicate, "Стол № 42 уже существует.")

        XCTAssertEqual(floor.addTable(number: 0, seats: 2, zone: "Бар"), "Номер стола должен быть больше нуля.")
        XCTAssertEqual(floor.addTable(number: 43, seats: 99, zone: "Бар"), "Количество мест должно быть от 1 до 30.")
    }

    func testOccupiedTableCannotBeDeleted() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 3 }))
        _ = try XCTUnwrap(floor.openOrder(for: table))
        XCTAssertTrue(TestSupport.waitUntil { floor.card(for: table.id)?.isOccupied == true })

        XCTAssertEqual(floor.deleteTable(table), "Сначала закройте заказ на этом столе.")
    }

    func testTableUpdateKeepsIdentity() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 5 }))
        XCTAssertNil(floor.updateTable(table, number: 5, seats: 6, zone: "Летняя веранда"))

        let updated = try db.read { try RestaurantTable.fetchOne(db, key: table.id) }
        XCTAssertEqual(updated?.seats, 6)
        XCTAssertEqual(updated?.zone, "Летняя веранда")
    }

    // MARK: - Full order lifecycle

    func testOrderLifecycleFromTapToPayment() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 2 }))
        let orderId = try XCTUnwrap(floor.openOrder(for: table))
        let dish = try XCTUnwrap(
            db.read { db in
                try MenuItem.filter(Column("name") == "Цезарь с курицей").fetchOne(db)
            }
        )

        let store = OrderStore(database: db, orderId: orderId)
        store.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { store.lines.count == 1 })

        XCTAssertEqual(store.total, dish.price)
        XCTAssertEqual(store.itemCount, 1)
        XCTAssertEqual(store.quantity(for: dish.id), 1)
        XCTAssertTrue(store.hasUnsentItems)
        XCTAssertEqual(store.tableNumber, 2)
        XCTAssertEqual(store.status, .active)

        // Second tap on the same dish bumps the quantity instead of adding a row.
        store.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { store.itemCount == 2 })
        XCTAssertEqual(store.lines.count, 1)
        XCTAssertEqual(store.total, dish.price * 2)

        XCTAssertTrue(store.sendToKitchen())
        XCTAssertTrue(TestSupport.waitUntil { store.lines.allSatisfy(\.isSent) })
        XCTAssertEqual(store.status, .sent)
        XCTAssertFalse(store.hasUnsentItems)

        XCTAssertTrue(store.pay(method: .cash))
        XCTAssertTrue(TestSupport.waitUntil { store.isPaid })
        XCTAssertTrue(store.didClose)
        XCTAssertEqual(store.paymentMethodTitle, "Наличные")
        XCTAssertEqual(store.order?.totalAmount, dish.price * 2)

        let freed = try db.read { try RestaurantTable.fetchOne(db, key: table.id) }
        XCTAssertEqual(freed?.status, TableStatus.free)
        XCTAssertNil(freed?.currentOrderId)

        XCTAssertTrue(TestSupport.waitUntil { floor.stats.paidOrdersToday == 1 })
        XCTAssertEqual(floor.stats.revenueToday, dish.price * 2)
    }

    func testPaidOrderIsImmutable() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 6 }))
        let orderId = try XCTUnwrap(floor.openOrder(for: table))
        let dish = try XCTUnwrap(db.read { db in try MenuItem.fetchOne(db) })

        let store = OrderStore(database: db, orderId: orderId)
        store.add(dish)
        XCTAssertTrue(TestSupport.waitUntil { store.lines.count == 1 })
        XCTAssertTrue(store.pay(method: .card))
        XCTAssertTrue(TestSupport.waitUntil { store.isPaid })

        let lineId = try XCTUnwrap(store.lines.first?.id)
        store.increment(lineId: lineId)
        store.decrement(lineId: lineId)
        store.remove(lineId: lineId)
        store.add(dish)
        XCTAssertFalse(store.sendToKitchen())

        XCTAssertTrue(TestSupport.waitUntil { store.itemCount == 1 }, "оплаченный счёт нельзя изменить")
        XCTAssertFalse(store.cancelOrder())
    }

    func testCancelOrderFreesTableAndDeletesBill() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 7 }))
        let orderId = try XCTUnwrap(floor.openOrder(for: table))

        let store = OrderStore(database: db, orderId: orderId)
        XCTAssertTrue(store.cancelOrder())
        XCTAssertTrue(TestSupport.waitUntil { store.didClose })

        let removed = try db.read { try Order.fetchOne(db, key: orderId) }
        XCTAssertNil(removed)
        let freed = try db.read { try RestaurantTable.fetchOne(db, key: table.id) }
        XCTAssertEqual(freed?.status, TableStatus.free)
    }

    func testGuestsAndNoteArePersisted() throws {
        let db = try TestSupport.makeDatabase()
        let floor = FloorStore(database: db)
        XCTAssertTrue(TestSupport.waitUntil { !floor.cards.isEmpty })

        let table = try XCTUnwrap(floor.tables.first(where: { $0.number == 8 }))
        let orderId = try XCTUnwrap(floor.openOrder(for: table))
        let store = OrderStore(database: db, orderId: orderId)

        store.updateGuests(6)
        store.updateNote("  подать позже  ")

        XCTAssertTrue(TestSupport.waitUntil { store.guests == 6 })
        XCTAssertTrue(TestSupport.waitUntil { store.note == "подать позже" })
    }
}
