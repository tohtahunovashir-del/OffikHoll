import Foundation

enum PriceParser {
    /// Accepts "450", "450,50", "1 250 ₽", "450.00 руб.", OCR confusions such
    /// as "4S0" or "1ООО", and returns a plain `Double`.
    static func value(from raw: String) -> Double? {
        var normalized = raw.lowercased()
        let noise = ["₽", "руб.", "рублей", "руб", "р.", "грн.", "грн", "₴", "$", "€", "usd", "eur", "р"]
        for token in noise {
            normalized = normalized.replacingOccurrences(of: token, with: " ")
        }
        normalized = normalized
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        let digitFixes: [Character: Character] = [
            "o": "0", "о": "0", "O": "0", "О": "0",
            "з": "3", "З": "3",
            "l": "1", "I": "1", "|": "1",
            "s": "5", "S": "5"
        ]
        var fixed = ""
        for character in normalized {
            if let replacement = digitFixes[character] {
                fixed.append(replacement)
            } else {
                fixed.append(character)
            }
        }
        fixed = fixed.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        fixed = fixed.replacingOccurrences(of: ",", with: ".")
        guard !fixed.isEmpty else { return nil }
        while fixed.hasSuffix(".") { fixed.removeLast() }
        let parts = fixed.split(separator: ".", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return nil }
        if parts.count > 2 {
            let integer = parts.dropLast().joined()
            let fraction = String(parts.last ?? "")
            guard let value = Double(integer + "." + fraction) else { return nil }
            return value
        }
        return Double(fixed)
    }

    static func editable(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}

enum Price {
    static let currency = "₽"

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        return formatter
    }()

    static func string(_ value: Double, showCurrency: Bool = true) -> String {
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return showCurrency ? "\(number) \(currency)" : number
    }

    static func compact(_ value: Double) -> String {
        if value >= 10_000 {
            let thousands = value / 1_000
            let formatted = String(format: "%.1f", thousands).replacingOccurrences(of: ".", with: ",")
            return "\(formatted) тыс. \(currency)"
        }
        return string(value)
    }
}
