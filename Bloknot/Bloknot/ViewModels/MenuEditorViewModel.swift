import Combine
import Foundation

final class MenuEditorViewModel: ObservableObject {
    @Published private(set) var catalog: MenuCatalog = .empty
    @Published var errorMessage: String?

    private let menuRepository: MenuRepository
    private var cancellables = Set<AnyCancellable>()

    init(menuRepository: MenuRepository = AppDependencies.shared.menuRepository) {
        self.menuRepository = menuRepository
        observe()
    }

    private func observe() {
        menuRepository
            .observeCatalog()
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось прочитать меню: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] catalog in
                self?.catalog = catalog
            })
            .store(in: &cancellables)
    }

    // MARK: - Derived

    var categories: [Category] { catalog.categories }

    func items(in categoryId: UUID) -> [MenuItem] {
        catalog.items.filter { $0.categoryId == categoryId }
    }

    func categoryName(for id: UUID) -> String {
        catalog.categories.first(where: { $0.id == id })?.name ?? Constants.defaultCategoryName
    }

    // MARK: - Actions

    func addCategory(_ name: String) {
        do {
            _ = try menuRepository.addCategory(named: name)
            HapticsService.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(_ category: Category) {
        do {
            try menuRepository.deleteCategory(id: category.id)
        } catch {
            errorMessage = "Не удалось удалить категорию: \(error.localizedDescription)"
        }
    }

    func addDish(name: String, priceText: String, categoryId: UUID) {
        guard let price = PriceParser.value(from: priceText) else {
            errorMessage = "Укажите цену блюда."
            return
        }
        do {
            _ = try menuRepository.addItem(name: name, price: price, categoryId: categoryId)
            HapticsService.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: MenuItem) {
        do {
            try menuRepository.deleteItem(id: item.id)
        } catch {
            errorMessage = "Не удалось удалить блюдо: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func importDishes(_ dishes: [ParsedDish]) -> Int {
        do {
            let inserted = try menuRepository.importDishes(dishes)
            HapticsService.success()
            return inserted
        } catch {
            errorMessage = "Не удалось добавить блюда: \(error.localizedDescription)"
            return 0
        }
    }
}
