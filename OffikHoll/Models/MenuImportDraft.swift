import Foundation

/// Transport model between the OCR review screen and the menu store.
struct MenuItemDraft: Equatable {
    var name: String
    var price: Double
    var categoryName: String
    var details: String

    init(name: String, price: Double, categoryName: String, details: String = "") {
        self.name = name
        self.price = price
        self.categoryName = categoryName
        self.details = details
    }
}

struct MenuImportResult: Equatable {
    var inserted: Int
    var skipped: Int
    var createdCategories: Int

    var summaryText: String {
        var parts: [String] = ["Добавлено блюд: \(inserted)"]
        if createdCategories > 0 {
            parts.append("новых категорий: \(createdCategories)")
        }
        if skipped > 0 {
            parts.append("пропущено: \(skipped)")
        }
        return parts.joined(separator: " · ")
    }
}
