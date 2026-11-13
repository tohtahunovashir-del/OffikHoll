import Foundation

/// Разбор цены из поля ввода и из OCR-строки.
enum PriceParser {
    static func value(from text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        cleaned = cleaned
            .replacingOccurrences(of: "₽", with: "")
            .replacingOccurrences(of: "₴", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "руб.", with: "")
            .replacingOccurrences(of: "руб", with: "")
            .replacingOccurrences(of: "р.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let allowed = cleaned.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == " " }
        var normalized = allowed.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count > 2 {
            let integer = parts.dropLast().joined()
            let decimal = String(parts[parts.count - 1])
            normalized = integer + "." + decimal
        } else if parts.count == 2, parts[1].count == 3, parts[0].count <= 3 {
            // «1.290» и «1,290» — это тысячи, а не 1,29 рубля.
            normalized = String(parts[0]) + String(parts[1])
        }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func editable(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}
