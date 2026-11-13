import Foundation

/// Денежные строки в русском формате: «1 290 ₽».
enum Money {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Число без валюты: «1 290».
    static func plain(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// Число с валютой: «1 290 ₽».
    static func string(_ value: Double) -> String {
        plain(value) + " ₽"
    }

    /// Компактная запись для карточек блюд.
    static func compact(_ value: Double) -> String {
        string(value)
    }
}

/// Русские склонения.
enum Plural {
    static func positions(_ count: Int) -> String {
        "\(count) \(word(count, one: "позиция", few: "позиции", many: "позиций"))"
    }

    static func items(_ count: Int) -> String {
        "\(count) \(word(count, one: "блюдо", few: "блюда", many: "блюд"))"
    }

    static func guests(_ count: Int) -> String {
        "\(count) \(word(count, one: "гость", few: "гостя", many: "гостей"))"
    }

    private static func word(_ count: Int, one: String, few: String, many: String) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        if mod100 >= 11 && mod100 <= 14 { return many }
        if mod10 == 1 { return one }
        if mod10 >= 2 && mod10 <= 4 { return few }
        return many
    }
}
