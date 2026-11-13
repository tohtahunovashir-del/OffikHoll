import Combine
import Foundation

final class OrderViewModel: ObservableObject {
    let table: DiningTable
    let orderId: UUID

    @Published private(set) var catalog: MenuCatalog = .empty
    @Published private(set) var snapshot: OrderSnapshot = .empty
    @Published var selectedCategoryId: UUID?
    @Published var errorMessage: String?
    @Published private(set) var isClosed = false

    private let menuRepository: MenuRepository
    private let orderRepository: OrderRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        table: DiningTable,
        orderId: UUID,
        menuRepository: MenuRepository = AppDependencies.shared.menuRepository,
        orderRepository: OrderRepository = AppDependencies.shared.orderRepository
    ) {
        self.table = table
        self.orderId = orderId
        self.menuRepository = menuRepository
        self.orderRepository = orderRepository
        observeMenu()
        observeOrder()
    }

    // MARK: - Observation

    private func observeMenu() {
        menuRepository
            .observeCatalog()
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось прочитать меню: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] catalog in
                guard let self = self else { return }
                self.catalog = catalog
                if self.selectedCategoryId == nil {
                    self.selectedCategoryId = catalog.categories.first?.id
                }
            })
            .store(in: &cancellables)
    }

    private func observeOrder() {
        orderRepository
            .observeOrder(id: orderId)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось прочитать заказ: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] snapshot in
                self?.snapshot = snapshot
            })
            .store(in: &cancellables)
    }

    // MARK: - Derived

    var categories: [Category] {
        catalog.categories
    }

    var dishes: [MenuItem] {
        let available = catalog.items.filter { $0.isAvailable }
        guard let categoryId = selectedCategoryId else { return available }
        return available.filter { $0.categoryId == categoryId }
    }

    var lines: [OrderItem] { snapshot.lines }
    var total: Double { snapshot.total }
    var itemCount: Int { snapshot.itemCount }
    var hasUnsent: Bool { snapshot.hasUnsent }
    var guests: Int { snapshot.order?.guests ?? 2 }

    func quantity(for menuItemId: UUID) -> Int {
        lines.filter { $0.menuItemId == menuItemId }.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Actions

    func select(categoryId: UUID) {
        selectedCategoryId = categoryId
        HapticsService.selection()
    }

    func add(_ item: MenuItem) {
        do {
            try orderRepository.add(menuItem: item, to: orderId)
            HapticsService.addDish()
        } catch {
            errorMessage = "Не удалось добавить блюдо: \(error.localizedDescription)"
            HapticsService.error()
        }
    }

    func increment(_ line: OrderItem) {
        do {
            try orderRepository.setQuantity(lineId: line.id, quantity: line.quantity + 1)
            HapticsService.tap()
        } catch {
            errorMessage = "Не удалось изменить количество: \(error.localizedDescription)"
        }
    }

    func decrement(_ line: OrderItem) {
        do {
            try orderRepository.setQuantity(lineId: line.id, quantity: line.quantity - 1)
            HapticsService.tap()
        } catch {
            errorMessage = "Не удалось изменить количество: \(error.localizedDescription)"
        }
    }

    func remove(_ line: OrderItem) {
        do {
            try orderRepository.removeLine(id: line.id)
        } catch {
            errorMessage = "Не удалось удалить позицию: \(error.localizedDescription)"
        }
    }

    func sendToKitchen() {
        guard hasUnsent else { return }
        do {
            try orderRepository.sendToKitchen(orderId: orderId)
            HapticsService.success()
        } catch {
            errorMessage = "Не удалось отправить на кухню: \(error.localizedDescription)"
            HapticsService.error()
        }
    }

    func pay() {
        guard !lines.isEmpty else {
            errorMessage = "В заказе нет позиций."
            return
        }
        do {
            try orderRepository.markPaid(orderId: orderId)
            isClosed = true
            HapticsService.success()
        } catch {
            errorMessage = "Не удалось закрыть счёт: \(error.localizedDescription)"
            HapticsService.error()
        }
    }

    func cancelOrder() {
        do {
            try orderRepository.cancelOrder(orderId: orderId)
            isClosed = true
        } catch {
            errorMessage = "Не удалось отменить заказ: \(error.localizedDescription)"
        }
    }
}
