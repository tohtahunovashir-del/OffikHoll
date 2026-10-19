import Foundation

/// One visual line produced by Vision. Confidence is carried all the way to
/// the review screen so the waiter can see what needs extra attention.
struct RecognizedLine: Equatable, Sendable {
    var text: String
    var confidence: Double
    var pageIndex: Int
}

struct ParsedMenuItem: Identifiable, Equatable {
    var id: UUID
    var name: String
    var price: Double
    var currency: String
    var portion: String
    var categoryName: String
    var pageIndex: Int
    var confidence: Double
    var rawLine: String

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        currency: String = "₽",
        portion: String = "",
        categoryName: String = "Разное",
        pageIndex: Int = 0,
        confidence: Double = 0.5,
        rawLine: String = ""
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.portion = portion
        self.categoryName = categoryName
        self.pageIndex = pageIndex
        self.confidence = confidence
        self.rawLine = rawLine
    }
}

/// Editable row on the interactive confirmation screen.
struct ScanDraft: Identifiable, Equatable {
    var id: UUID
    var name: String
    var priceText: String
    var categoryName: String
    var portion: String
    var currency: String
    var confidence: Double
    var pageIndex: Int
    var isIncluded: Bool

    init(
        id: UUID = UUID(),
        name: String,
        priceText: String,
        categoryName: String,
        portion: String = "",
        currency: String = "₽",
        confidence: Double = 0.5,
        pageIndex: Int = 0,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.priceText = priceText
        self.categoryName = categoryName
        self.portion = portion
        self.currency = currency
        self.confidence = confidence
        self.pageIndex = pageIndex
        self.isIncluded = isIncluded
    }

    init(parsed: ParsedMenuItem) {
        self.init(
            name: parsed.name,
            priceText: PriceParser.editable(parsed.price),
            categoryName: parsed.categoryName,
            portion: parsed.portion,
            currency: parsed.currency,
            confidence: parsed.confidence,
            pageIndex: parsed.pageIndex,
            isIncluded: true
        )
    }

    var price: Double? {
        PriceParser.value(from: priceText)
    }

    var isValid: Bool {
        price != nil && name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var confidenceLevel: Int {
        if confidence >= 0.8 { return 2 }
        if confidence >= 0.55 { return 1 }
        return 0
    }
}
