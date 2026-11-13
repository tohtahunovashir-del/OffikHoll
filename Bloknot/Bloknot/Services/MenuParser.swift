import CoreGraphics
import Foundation

/// Один распознанный фрагмент строки (Vision отдаёт по наблюдению на фрагмент).
struct RecognizedSegment: Hashable {
    let text: String
    let confidence: Float
    let box: CGRect
}

/// Визуальная строка: фрагменты, склеенные по вертикальному перекрытию.
struct RecognizedLine: Hashable {
    let text: String
    let confidence: Float
    let box: CGRect
    let segments: [RecognizedSegment]
}

/// Блюдо, извлечённое из меню.
struct ParsedDish: Identifiable, Hashable {
    let id: UUID
    var name: String
    var price: Double
    var category: String
    var confidence: Double
    var rawText: String

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        category: String,
        confidence: Double,
        rawText: String = ""
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.confidence = confidence
        self.rawText = rawText
    }
}

/// Разбор меню: от строк OCR к списку блюд.
///
/// Логика намеренно детерминированная и без ML:
/// 1. цена ищется только в конце строки (последнее число), поэтому годы,
///    объёмы и проценты внутри названия не путаются с ценой;
/// 2. тысячи поддерживаются в трёх видах — `1 290`, `1.290`, `1,290`;
/// 3. строки-заголовки, шум и цены без названия отбрасываются;
/// 4. перенесённые названия склеиваются, если продолжение начинается
///    со строчной буквы или предыдущая строка кончается предлогом.
struct MenuParser {

    // MARK: - Public

    func parse(lines: [RecognizedLine], knownCategories: [String] = []) -> [ParsedDish] {
        let ordered = lines.sorted { $0.box.midY > $1.box.midY }

        var dishes: [ParsedDish] = []
        var currentCategory = Constants.defaultCategoryName
        var pendingName: String?
        var pendingIndex = -1
        var seen = Set<String>()

        for (index, line) in ordered.enumerated() {
            let text = Self.normalizedWhitespace(line.text)
            guard !text.isEmpty else { continue }

            if let header = Self.categoryHeader(for: text, knownCategories: knownCategories) {
                currentCategory = header
                pendingName = nil
                continue
            }

            if Self.isNoise(text) {
                pendingName = nil
                continue
            }

            guard let parsed = Self.trailingPrice(in: text) else {
                if Self.isNameLike(text) {
                    pendingName = text
                    pendingIndex = index
                } else {
                    pendingName = nil
                }
                continue
            }

            var name = parsed.name
            if let pending = pendingName, pendingIndex == index - 1,
               Self.shouldMerge(pending: pending, with: name) {
                name = Self.cleanName(pending + " " + name)
            }
            pendingName = nil

            guard Self.isValid(name: name, price: parsed.price) else { continue }

            let key = Self.normalizedKey(name) + "|" + String(format: "%.2f", parsed.price)
            guard seen.insert(key).inserted else { continue }

            var confidence = 0.35 + Double(line.confidence) * 0.5
            if parsed.hadCurrency { confidence += 0.05 }
            if name.count >= 6 { confidence += 0.03 }
            if parsed.price >= 100 { confidence += 0.02 }
            confidence += Self.geometryBonus(for: line)
            confidence = min(0.99, max(0.05, confidence))

            dishes.append(
                ParsedDish(
                    name: name,
                    price: parsed.price,
                    category: currentCategory,
                    confidence: confidence,
                    rawText: line.text
                )
            )
        }

        return dishes
    }

    /// Удобная точка входа для тестов и буфера обмена.
    func parse(text: String, knownCategories: [String] = []) -> [ParsedDish] {
        let lines = text
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, raw -> RecognizedLine? in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let y = 1.0 - Double(index) * 0.04
                let box = CGRect(x: 0.05, y: max(0, y), width: 0.9, height: 0.03)
                return RecognizedLine(
                    text: trimmed,
                    confidence: 0.9,
                    box: box,
                    segments: [RecognizedSegment(text: trimmed, confidence: 0.9, box: box)]
                )
            }
        return parse(lines: lines, knownCategories: knownCategories)
    }

    // MARK: - Price

    private static let priceRegex = try! NSRegularExpression(
        pattern: #"(?<![\w.,])(\d{1,3}(?:[ .]\d{3})+|\d{1,6})(?:[.,](\d{1,2}))?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let currencyWords: [String] = [
        "грн.", "руб.", "рублей", "рубля", "грн", "руб", "usd", "eur", "р.", "р"
    ]

    private static let currencySymbols = "₽₴$€"

    private static func trailingPrice(
        in text: String
    ) -> (name: String, price: Double, hadCurrency: Bool)? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " .;-–—,="))
        let stripped = stripCurrency(trimmed)
        guard !stripped.text.isEmpty else { return nil }

        let working = stripped.text
        let fullRange = NSRange(location: 0, length: (working as NSString).length)
        guard let match = priceRegex.firstMatch(in: working, options: [], range: fullRange) else {
            return nil
        }

        guard match.range(at: 1).location != NSNotFound,
              let integerRange = Range(match.range(at: 1), in: working) else {
            return nil
        }

        let integerPart = String(working[integerRange])
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        var valueString = integerPart
        if match.range(at: 2).location != NSNotFound,
           let decimalRange = Range(match.range(at: 2), in: working) {
            valueString += "." + String(working[decimalRange])
        }

        guard let price = Double(valueString) else { return nil }

        let nameRange = NSRange(location: 0, length: match.range.location)
        guard let swiftNameRange = Range(nameRange, in: working) else { return nil }
        var name = String(working[swiftNameRange])
        if stripped.hadCurrency {
            name = stripCurrency(name).text
        }

        return (cleanName(name), price, stripped.hadCurrency)
    }

    private static func stripCurrency(_ input: String) -> (text: String, hadCurrency: Bool) {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var hadCurrency = false
        var didChange = true

        while didChange && !text.isEmpty {
            didChange = false
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if let last = trimmed.last, currencySymbols.contains(last) {
                text = String(trimmed.dropLast())
                hadCurrency = true
                didChange = true
                continue
            }

            let lowered = trimmed.lowercased()
            for word in currencyWords where lowered.hasSuffix(word) {
                let prefix = String(trimmed.dropLast(word.count))
                let boundaryOK = prefix.isEmpty
                    || prefix.hasSuffix(" ")
                    || (prefix.last?.isNumber ?? false)
                if boundaryOK {
                    text = prefix
                    hadCurrency = true
                    didChange = true
                    break
                }
            }
        }

        return (text.trimmingCharacters(in: .whitespacesAndNewlines), hadCurrency)
    }

    // MARK: - Categories

    static func normalizedKey(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func categoryHeader(for text: String, knownCategories: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 48 else { return nil }
        guard !trimmed.contains(where: { $0.isNumber }) else { return nil }

        let letterCount = trimmed.filter { $0.isLetter }.count
        guard letterCount >= 3 else { return nil }
        guard trimmed.split(separator: " ").count <= 5 else { return nil }

        let key = normalizedKey(trimmed)
        if let match = knownCategories.first(where: { normalizedKey($0) == key }) {
            return match
        }

        // OCR часто теряет одно слово заголовка: «САЛАТЫ» вместо
        // «Салаты дня». Принимаем совпадение по началу на границе слова.
        if let match = knownCategories.first(where: { known in
            let knownKey = normalizedKey(known)
            return knownKey.hasPrefix(key + " ") || key.hasPrefix(knownKey + " ")
        }) {
            return match
        }

        if trimmed.hasSuffix(":") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        }

        let isUpper = trimmed == trimmed.uppercased() && trimmed != trimmed.lowercased()
        if isUpper {
            return trimmed.lowercased().capitalized(with: Locale(identifier: "ru_RU"))
        }

        return nil
    }

    // MARK: - Cleaning & validation

    static func normalizedWhitespace(_ value: String) -> String {
        var text = value
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        text = text.replacingOccurrences(of: "\u{202F}", with: " ")
        text = text.replacingOccurrences(of: "\u{2009}", with: " ")
        text = text.replacingOccurrences(of: "\u{200B}", with: "")
        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanName(_ raw: String) -> String {
        var name = raw
        name = name.replacingOccurrences(of: #"[.·…]{2,}"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " .-–—:;,|/\\\"'«»"))
        return name
    }

    private static func isValid(name: String, price: Double) -> Bool {
        guard !name.isEmpty, name.count <= 80 else { return false }
        guard name.filter({ $0.isLetter }).count >= 2 else { return false }
        guard price >= Constants.ocrMinimumPrice, price <= Constants.ocrMaximumPrice else { return false }
        return !isNoise(name)
    }

    // MARK: - Noise

    private static let noiseWords: Set<String> = [
        "меню", "menu", "стр", "итого", "total", "счет", "счёт", "кафе",
        "ресторан", "тел", "телефон", "адрес", "ндс", "скидка", "официант",
        "доставка", "www", "http", "page", "бар"
    ]

    private static let noisePhrases: [String] = [
        "к оплате", "спасибо за визит", "часы работы", "время работы",
        "сервисный сбор", "приятного аппетита", "оставьте отзыв", "qr-код"
    ]

    static func isNoise(_ text: String) -> Bool {
        let lower = text.lowercased()
        if noisePhrases.contains(where: { lower.contains($0) }) { return true }
        if lower.contains("http") || lower.contains("www.") { return true }

        let tokens = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.contains { noiseWords.contains($0) }
    }

    private static func isNameLike(_ text: String) -> Bool {
        guard text.filter({ $0.isLetter }).count >= 2 else { return false }
        guard text.count <= 70 else { return false }
        guard text.split(separator: " ").count <= 9 else { return false }
        guard let last = text.last, !last.isNumber else { return false }
        return !isNoise(text)
    }

    // MARK: - Wrapped names

    private static let connectors: Set<String> = [
        "и", "с", "со", "на", "из", "для", "или", "в", "во", "по",
        "от", "до", "под", "над", "без", "при", "о", "об"
    ]

    private static func shouldMerge(pending: String, with name: String) -> Bool {
        guard let first = name.first else { return false }
        if first.isLowercase { return true }
        guard let lastWord = pending.split(separator: " ").last else { return false }
        return connectors.contains(String(lastWord).lowercased())
    }

    // MARK: - Geometry

    /// Если последний фрагмент строки стоит у правого края — это почти
    /// наверняка колонка цен; если у левого — скорее объём или год.
    private static func geometryBonus(for line: RecognizedLine) -> Double {
        guard let last = line.segments.last else { return 0 }
        guard let lastChar = last.text.last, lastChar.isNumber else { return 0 }
        if last.box.minX > 0.5 { return 0.05 }
        if last.box.maxX < 0.3 { return -0.08 }
        return 0
    }
}
