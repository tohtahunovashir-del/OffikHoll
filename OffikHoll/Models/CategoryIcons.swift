import Foundation

/// A curated set of SF Symbols that are guaranteed to exist on iOS 16.
/// Used by the category editor and by the OCR pipeline when it creates
/// categories automatically from scanned menu headers.
enum CategoryIcons {
    static let defaultIcon = "fork.knife"

    static let all: [String] = [
        "fork.knife",
        "leaf.fill",
        "flame.fill",
        "cup.and.saucer.fill",
        "heart.fill",
        "drop.fill",
        "sun.max.fill",
        "circle.grid.3x3.fill",
        "bag.fill",
        "takeoutbag.and.cup.and.straw.fill"
    ]

    static func icon(forCategoryNamed name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("салат") || lower.contains("овощ") || lower.contains("гарнир") {
            return "leaf.fill"
        }
        if lower.contains("суп") || lower.contains("бульон") {
            return "cup.and.saucer.fill"
        }
        if lower.contains("гриль") || lower.contains("мяс") || lower.contains("стейк") {
            return "flame.fill"
        }
        if lower.contains("десерт") || lower.contains("слад") || lower.contains("морож") {
            return "heart.fill"
        }
        if lower.contains("напит") || lower.contains("бар") || lower.contains("вин") || lower.contains("коктейл") {
            return "drop.fill"
        }
        if lower.contains("завтрак") {
            return "sun.max.fill"
        }
        if lower.contains("паст") || lower.contains("пицц") {
            return "circle.grid.3x3.fill"
        }
        if lower.contains("хлеб") || lower.contains("выпеч") {
            return "bag.fill"
        }
        if lower.contains("бургер") || lower.contains("сэндвич") || lower.contains("фастфуд") {
            return "takeoutbag.and.cup.and.straw.fill"
        }
        return defaultIcon
    }
}
