import Foundation
import GRDB
import Combine

/// Reactive menu store. All reads go through a single `ValueObservation`,
/// all writes go through GRDB transactions. Views never reload manually:
/// a write triggers the observation and the `@Published` arrays update.
final class MenuStore: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published private(set) var items: [MenuItem] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let database: DatabaseQueue
    private var observationCancellable: AnyCancellable?

    init(database: DatabaseQueue) {
        self.database = database
        observe()
    }

    private func observe() {
        ValueObservation
            .tracking { db in
                MenuSnapshot(
                    categories: try Category
                        .order(Category.Columns.sortOrder, Category.Columns.name)
                        .fetchAll(db),
                    items: try MenuItem
                        .order(MenuItem.Columns.name)
                        .fetchAll(db)
                )
            }
            .publisher(in: database)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = "Не удалось прочитать меню: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] snapshot in
                self?.categories = snapshot.categories
                self?.items = snapshot.items
                self?.isLoading = false
            })
            .store(in: &observationCancellable)
    }

    // MARK: - Derived data

    func items(in categoryId: UUID) -> [MenuItem] {
        items.filter { $0.categoryId == categoryId }
    }

    func itemCount(in categoryId: UUID) -> Int {
        items.reduce(0) { $0 + ($1.categoryId == categoryId ? 1 : 0) }
    }

    func categoryName(for id: UUID) -> String {
        categories.first(where: { $0.id == id })?.name ?? "Без категории"
    }

    func categoryId(named name: String) -> UUID? {
        let key = Self.normalized(name)
        return categories.first(where: { Self.normalized($0.name) == key })?.id
    }

    var availableItems: [MenuItem] {
        items.filter(\.isAvailable)
    }

    var categoryNames: [String] {
        categories.map(\.name)
    }

    // MARK: - Categories

    @discardableResult
    func addCategory(name: String, icon: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Название категории должно содержать минимум 2 символа."
            return nil
        }
        guard !categories.contains(where: { Self.normalized($0.name) == Self.normalized(trimmed) }) else {
            errorMessage = "Категория «\(trimmed)» уже существует."
            return nil
        }
        let nextOrder = (categories.map(\.order).max() ?? -1) + 1
        let newCategory = Category(id: UUID(), name: trimmed, order: nextOrder, icon: icon)
        do {
            try database.write { db in
                try newCategory.insert(db)
            }
            return newCategory.id
        } catch {
            errorMessage = "Не удалось создать категорию: \(error.localizedDescription)"
            return nil
        }
    }

    func updateCategory(_ category: Category, name: String, icon: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Название категории слишком короткое."
            return
        }
        guard !categories.contains(where: {
            $0.id != category.id && Self.normalized($0.name) == Self.normalized(trimmed)
        }) else {
            errorMessage = "Категория «\(trimmed)» уже существует."
            return
        }
        var updated = category
        updated.name = trimmed
        updated.icon = icon
        do {
            try database.write { db in
                try updated.update(db)
            }
        } catch {
            errorMessage = "Не удалось сохранить категорию: \(error.localizedDescription)"
        }
    }

    func deleteCategory(_ category: Category) {
        do {
            try database.write { db in
                _ = try category.delete(db)
            }
        } catch {
            errorMessage = "Не удалось удалить категорию: \(error.localizedDescription)"
        }
    }

    // MARK: - Items

    @discardableResult
    func addItem(
        name: String,
        price: Double,
        categoryId: UUID,
        details: String = "",
        isAvailable: Bool = true
    ) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Название блюда слишком короткое."
            return nil
        }
        guard price > 0 else {
            errorMessage = "Укажите цену больше нуля."
            return nil
        }
        guard categories.contains(where: { $0.id == categoryId }) else {
            errorMessage = "Выберите категорию для блюда."
            return nil
        }
        let item = MenuItem(
            name: trimmed,
            price: price,
            categoryId: categoryId,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            isAvailable: isAvailable
        )
        do {
            try database.write { db in
                try item.insert(db)
            }
            return item.id
        } catch {
            errorMessage = "Не удалось добавить блюдо: \(error.localizedDescription)"
            return nil
        }
    }

    func updateItem(_ item: MenuItem) {
        var updated = item
        updated.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.details = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard updated.name.count >= 2, updated.price > 0 else {
            errorMessage = "Проверьте название и цену блюда."
            return
        }
        do {
            try database.write { db in
                try updated.update(db)
            }
        } catch {
            errorMessage = "Не удалось сохранить блюдо: \(error.localizedDescription)"
        }
    }

    func deleteItem(_ item: MenuItem) {
        do {
            try database.write { db in
                _ = try item.delete(db)
            }
        } catch {
            errorMessage = "Не удалось удалить блюдо: \(error.localizedDescription)"
        }
    }

    func toggleAvailability(_ item: MenuItem) {
        var updated = item
        updated.isAvailable.toggle()
        updateItem(updated)
    }

    func moveItem(_ item: MenuItem, to categoryId: UUID) {
        var updated = item
        updated.categoryId = categoryId
        updateItem(updated)
    }

    // MARK: - Scanner import

    func importMenuItems(
        _ drafts: [MenuItemDraft],
        createMissingCategories: Bool = true,
        skipDuplicates: Bool = true,
        fallbackCategoryId: UUID? = nil
    ) -> MenuImportResult? {
        guard !drafts.isEmpty else {
            errorMessage = "Нет блюд для добавления."
            return nil
        }
        do {
            let result = try database.write { db -> MenuImportResult in
                var categories = try Category
                    .order(Category.Columns.sortOrder)
                    .fetchAll(db)
                var idsByName: [String: UUID] = [:]
                for category in categories {
                    idsByName[Self.normalized(category.name)] = category.id
                }
                var nextOrder = (categories.map(\.order).max() ?? -1) + 1
                let existingItems = try MenuItem.fetchAll(db)
                var existingKeys = Set(existingItems.map {
                    "\($0.categoryId.uuidString)|\(Self.normalized($0.name))"
                })

                var inserted = 0
                var skipped = 0
                var createdCategories = 0
                let now = Date()

                for draft in drafts {
                    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard name.count >= 2, draft.price > 0 else {
                        skipped += 1
                        continue
                    }
                    let requestedCategory = draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let categoryKey = Self.normalized(requestedCategory.isEmpty ? "Разное" : requestedCategory)
                    var categoryId = idsByName[categoryKey]

                    if categoryId == nil {
                        if createMissingCategories {
                            let title = requestedCategory.isEmpty ? "Разное" : requestedCategory
                            let category = Category(
                                name: title,
                                order: nextOrder,
                                icon: CategoryIcons.icon(forCategoryNamed: title)
                            )
                            try category.insert(db)
                            categories.append(category)
                            idsByName[categoryKey] = category.id
                            categoryId = category.id
                            nextOrder += 1
                            createdCategories += 1
                        } else if let fallback = fallbackCategoryId,
                                  categories.contains(where: { $0.id == fallback }) {
                            categoryId = fallback
                        }
                    }

                    guard let resolvedCategoryId = categoryId else {
                        skipped += 1
                        continue
                    }

                    let duplicateKey = "\(resolvedCategoryId.uuidString)|\(Self.normalized(name))"
                    if skipDuplicates, existingKeys.contains(duplicateKey) {
                        skipped += 1
                        continue
                    }

                    let item = MenuItem(
                        name: name,
                        price: draft.price,
                        categoryId: resolvedCategoryId,
                        details: draft.details,
                        isAvailable: true,
                        createdAt: now
                    )
                    try item.insert(db)
                    existingKeys.insert(duplicateKey)
                    inserted += 1
                }

                return MenuImportResult(
                    inserted: inserted,
                    skipped: skipped,
                    createdCategories: createdCategories
                )
            }
            return result
        } catch {
            errorMessage = "Не удалось добавить распознанные блюда: \(error.localizedDescription)"
            return nil
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
