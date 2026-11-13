import Foundation

/// Единственный контейнер зависимостей. Создаётся один раз при старте.
final class AppDependencies {
    static let shared = AppDependencies()

    let databaseManager: DatabaseManager
    let menuRepository: MenuRepository
    let tableRepository: TableRepository
    let orderRepository: OrderRepository

    private init() {
        let manager = DatabaseManager.shared
        databaseManager = manager
        menuRepository = MenuRepository(database: manager.database)
        tableRepository = TableRepository(database: manager.database)
        orderRepository = OrderRepository(database: manager.database)
    }
}
