import Foundation

/// Turns raw OCR lines into structured menu rows.
///
/// Pipeline:
/// 1. Normalisation (NBSP, typographic dashes, bullets, numbering).
/// 2. Category header detection (known Russian headers, ALL CAPS headers,
///    colons and already existing category names).
/// 3. Item extraction: trailing / leading prices, dotted leaders, optional
///    portions, currency detection and OCR digit fixes.
/// 4. Wrapped line recovery: a dish name split over 2–3 visual lines is
///    re-joined with its price.
/// 5. Deduplication across pages.
struct MenuParser {
    static let defaultCurrency = "₽"

    func parse(
        lines: [RecognizedLine],
        existingCategories: [String] = []
    ) -> [ParsedMenuItem] {
        let prepared = Self.prepare(lines)
        guard !prepared.isEmpty else { return [] }

        var results: [ParsedMenuItem] = []
        var currentCategory = ""
        var index = 0

        while index < prepared.count {
            let line = prepared[index]
            let text = line.text
            index += 1

            guard !text.isEmpty, !Self.isNoise(text) else { continue }

            if let header = Self.categoryHeader(for: text, existing: existingCategories) {
                currentCategory = header
                continue
            }

            if let item = parseItem(
                text,
                line: line,
                category: currentCategory
            ) {
                results.append(item)
                continue
            }

            // Recover names wrapped over several lines (very common when a
            // menu uses narrow columns or dotted price leaders).
            var combined = text
            var combinedConfidence = line.confidence
            var nextIndex = index
            var consumed = 0
            var joined: ParsedMenuItem?

            while consumed < 2, nextIndex < prepared.count {
                let nextText = prepared[nextIndex].text
                guard !nextText.isEmpty,
                      !Self.isNoise(nextText),
                      Self.canBeWrappedName(combined) else { break }
                guard nextText.count <= 90 else { break }
                guard Self.isPriceOnly(nextText) || Self.canBeWrappedName(nextText) else { break }
                guard Self.categoryHeader(for: nextText, existing: existingCategories) == nil else { break }

                // A short title followed by a complete dish row is most likely
                // an unknown category header, not a wrapped dish name.
                let nextLooksLikeFullItem = !Self.isPriceOnly(nextText)
                    && Self.trailingPriceRegex.firstMatch(
                        in: nextText,
                        range: NSRange(nextText.startIndex..., in: nextText)
                    ) != nil
                if nextLooksLikeFullItem && combined.split(separator: " ").count < 3 {
                    break
                }

                let candidate = combined + " " + nextText
                let candidateConfidence = min(combinedConfidence, prepared[nextIndex].confidence)
                if let item = parseItem(
                    candidate,
                    line: RecognizedLine(
                        text: candidate,
                        confidence: candidateConfidence,
                        pageIndex: line.pageIndex
                    ),
                    category: currentCategory
                ) {
                    joined = item
                    consumed += 1
                    nextIndex += 1
                    break
                }

                guard Self.canBeWrappedName(nextText) else { break }
                combined = candidate
                combinedConfidence = candidateConfidence
                consumed += 1
                nextIndex += 1
            }

            if let joined {
                results.append(joined)
                index = nextIndex
            }
        }

        return Self.deduplicate(results)
    }

    /// Convenience API for pasted text (useful when a restaurant already has
    /// the menu in a text document).
    func parse(text: String, existingCategories: [String] = []) -> [ParsedMenuItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { RecognizedLine(text: $0, confidence: 1.0, pageIndex: 0) }
        return parse(lines: lines, existingCategories: existingCategories)
    }

    // MARK: - Item parsing

    private func parseItem(
        _ rawText: String,
        line: RecognizedLine,
        category: String
    ) -> ParsedMenuItem? {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        text = Self.stripBullets(text)
        guard text.count >= 3, text.count <= 160 else { return nil }
        guard !Self.isNoise(text) else { return nil }

        var name = ""
        var priceString = ""
        var currency = ""
        var portion = ""
        var usedLeader = false

        if let match = Self.sizePriceRegex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) {
            name = Self.capture("name", in: text, match: match) ?? ""
            portion = (Self.capture("portion", in: text, match: match) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            priceString = Self.capture("price", in: text, match: match) ?? ""
            currency = (Self.capture("currency", in: text, match: match) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let match = Self.trailingPriceRegex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) {
            name = Self.capture("name", in: text, match: match) ?? ""
            priceString = Self.capture("price", in: text, match: match) ?? ""
            currency = (Self.capture("currency", in: text, match: match) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            usedLeader = text.range(of: #"[.·…]{2,}"#, options: .regularExpression) != nil
        } else if let match = Self.leadingPriceRegex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) {
            priceString = Self.capture("price", in: text, match: match) ?? ""
            currency = (Self.capture("currency", in: text, match: match) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            name = Self.capture("name", in: text, match: match) ?? ""
        } else {
            return nil
        }

        guard let price = PriceParser.value(from: priceString), price >= 1, price <= 1_000_000 else {
            return nil
        }

        name = Self.cleanName(name)

        if portion.isEmpty, let match = Self.portionRegex.firstMatch(
            in: name,
            range: NSRange(name.startIndex..., in: name)
        ) {
            portion = (Self.capture("portion", in: name, match: match) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = Range(match.range, in: name) {
                name.removeSubrange(range)
            }
            name = Self.cleanName(name)
        }

        let letterCount = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digitCount = name.filter(\.isNumber).count
        guard letterCount >= 2 else { return nil }
        guard digitCount <= max(3, name.count / 2) else { return nil }
        guard name.count >= 2, name.count <= 90 else { return nil }
        let lowerName = name.lowercased()
        guard !Self.noiseFragments.contains(where: { lowerName == $0 || lowerName.hasPrefix($0 + " ") }) else {
            return nil
        }

        if name == name.uppercased() && name != name.lowercased() {
            name = name.capitalized(with: Locale(identifier: "ru_RU"))
        }

        var confidence = 0.30 + line.confidence * 0.50
        if !currency.isEmpty { confidence += 0.05 }
        if usedLeader { confidence += 0.05 }
        if price >= 40 { confidence += 0.04 }
        if (4...70).contains(name.count) { confidence += 0.04 }
        if !portion.isEmpty { confidence += 0.02 }
        confidence = min(0.99, max(0.05, confidence))

        return ParsedMenuItem(
            name: name,
            price: price,
            currency: currency.isEmpty ? Self.defaultCurrency : currency,
            portion: portion,
            categoryName: category.isEmpty ? "Разное" : category,
            pageIndex: line.pageIndex,
            confidence: confidence,
            rawLine: rawText
        )
    }

    // MARK: - Category headers

    private struct CategoryHint {
        let key: String
        let title: String
    }

    private static let categoryHints: [CategoryHint] = [
        CategoryHint(key: "салаты", title: "Салаты"),
        CategoryHint(key: "закуски", title: "Закуски"),
        CategoryHint(key: "холодные закуски", title: "Закуски"),
        CategoryHint(key: "супы", title: "Супы"),
        CategoryHint(key: "первые блюда", title: "Супы"),
        CategoryHint(key: "горячее", title: "Горячее"),
        CategoryHint(key: "горячие блюда", title: "Горячее"),
        CategoryHint(key: "гриль", title: "Гриль"),
        CategoryHint(key: "стейки", title: "Гриль"),
        CategoryHint(key: "паста", title: "Паста и пицца"),
        CategoryHint(key: "пасты", title: "Паста и пицца"),
        CategoryHint(key: "пицца", title: "Паста и пицца"),
        CategoryHint(key: "десерты", title: "Десерты"),
        CategoryHint(key: "сладкое", title: "Десерты"),
        CategoryHint(key: "напитки", title: "Напитки"),
        CategoryHint(key: "завтраки", title: "Завтраки"),
        CategoryHint(key: "бургеры", title: "Бургеры"),
        CategoryHint(key: "суши", title: "Суши"),
        CategoryHint(key: "роллы", title: "Суши"),
        CategoryHint(key: "рыба", title: "Рыба"),
        CategoryHint(key: "мясо", title: "Мясо"),
        CategoryHint(key: "гарниры", title: "Гарниры"),
        CategoryHint(key: "соусы", title: "Соусы"),
        CategoryHint(key: "хлеб", title: "Хлеб"),
        CategoryHint(key: "детское меню", title: "Детское меню"),
        CategoryHint(key: "винная карта", title: "Винная карта"),
        CategoryHint(key: "коктейли", title: "Коктейли"),
        CategoryHint(key: "пиво", title: "Пиво"),
        CategoryHint(key: "бар", title: "Бар")
    ]

    private static func categoryHeader(for text: String, existing: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 48 else { return nil }
        guard !trimmed.contains(where: { $0.isNumber }) else { return nil }
        let letters = trimmed.filter(\.isLetter).count
        guard letters >= 3 else { return nil }
        let words = trimmed.split(separator: " ")
        guard words.count <= 6 else { return nil }

        let normalizedExisting = existing.first {
            Self.normalizeKey($0) == Self.normalizeKey(trimmed)
        }
        if let existingMatch = normalizedExisting { return existingMatch }

        var lower = trimmed.lowercased()
        lower = lower.trimmingCharacters(in: CharacterSet(charactersIn: " :.-—–"))
        let base = lower
            .components(separatedBy: " (")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? lower

        for hint in categoryHints {
            if base == hint.key || base.hasPrefix(hint.key + " ") {
                return hint.title
            }
        }

        let isAllUpper = trimmed == trimmed.uppercased() && trimmed != trimmed.lowercased()
        let endsWithColon = trimmed.hasSuffix(":")
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " :"))
        if endsWithColon && words.count <= 5 {
            return cleaned
        }
        if isAllUpper && words.count >= 2 && words.count <= 5 {
            return cleaned
        }
        return nil
    }

    private static func normalizeKey(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " :.-—–"))
    }

    // MARK: - Normalisation helpers

    private static let noiseFragments: [String] = [
        "http", "www.", "instagram", "telegram", "t.me", "@", "тел.", "телефон",
        "адрес", "часы работы", "итого", "к оплате", "обслуживание",
        "сервисный сбор", "ндс", "скидка", "доставка", "wi-fi", "wifi",
        "официант", "оставьте отзыв", "qr-код", "qr", "приятного аппетита",
        "бронь", "бронирование", "счет", "счёт", "спасибо", "добро пожаловать"
    ]

    private static func isNoise(_ text: String) -> Bool {
        let lower = text.lowercased()
        if noiseFragments.contains(where: { lower.contains($0) }) {
            return true
        }
        if lower.contains("%") && (lower.contains("скид") || lower.contains("discount")) {
            return true
        }
        return false
    }

    private static func stripBullets(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(
            of: #"^[\s•·*+~|]+"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"^\d{1,2}[.)]\s+"#,
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanName(_ raw: String) -> String {
        var name = raw
        name = name.replacingOccurrences(of: #"[.·…]{2,}"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"^\d{1,3}\s*[×xX]\s+"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+\d{1,6}\s*[/\\]\s*$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " \t.-–—:;,«»\"'`/\\|"))
        return name
    }

    private static func prepare(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        var result: [RecognizedLine] = []
        for line in lines {
            let parts = line.text.components(separatedBy: .newlines)
            for part in parts {
                var text = part
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .replacingOccurrences(of: "\u{202F}", with: " ")
                    .replacingOccurrences(of: "…", with: " ")
                    .replacingOccurrences(of: "–", with: "-")
                    .replacingOccurrences(of: "—", with: "-")
                text = text.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                text = stripBullets(text)
                guard !text.isEmpty else { continue }
                result.append(RecognizedLine(
                    text: text,
                    confidence: line.confidence,
                    pageIndex: line.pageIndex
                ))
            }
        }
        return result
    }

    private static func canBeWrappedName(_ text: String) -> Bool {
        guard text.count <= 90 else { return false }
        let letterCount = text.filter(\.isLetter).count
        guard letterCount >= 2 else { return false }
        let words = text.split(separator: " ")
        guard words.count <= 9 else { return false }
        // Do not glue a complete price row to the next line.
        if text.range(of: #"\d+\s*(₽|руб|р\.)"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private static func deduplicate(_ items: [ParsedMenuItem]) -> [ParsedMenuItem] {
        var seen = Set<String>()
        var result: [ParsedMenuItem] = []
        for item in items {
            let key = normalizeKey(item.name) + "|" + String(format: "%.2f", item.price)
            if seen.insert(key).inserted {
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Regexes

    // Price shapes: 450, 450.50, 450,50, 1 250, 1 250,00.
    // Currency is optional because many menus print plain numbers.
    private static let currencyGroup = #"(?:руб(?:\.|лей|ля|ль)?|р\.|₽|грн\.?|₴|\$|€|usd|eur)"#

    private static let trailingPriceRegex = try! NSRegularExpression(
        pattern: #"^(?<name>.+?)\s*(?:[.·…]{2,}\s*)?(?<price>(?:\d{1,3}(?:[  \u00A0\u202F]\d{3})+|\d{1,6})(?:[.,]\d{1,2})?)\s*(?<currency>"# + currencyGroup + #")?\.?$"#,
        options: [.caseInsensitive]
    )

    private static let leadingPriceRegex = try! NSRegularExpression(
        pattern: #"^(?<price>(?:\d{1,3}(?:[  \u00A0\u202F]\d{3})+|\d{1,6})(?:[.,]\d{1,2})?)\s*(?<currency>"# + currencyGroup + #")?\s+(?<name>[\p{L}].+)$"#,
        options: [.caseInsensitive]
    )

    private static let priceOnlyRegex = try! NSRegularExpression(
        pattern: #"^(?:(?:от\s+)?(?:\d{1,3}(?:[  \u00A0\u202F]\d{3})+|\d{1,6})(?:[.,]\d{1,2})?\s*(?<currency>"# + currencyGroup + #")?\.?)$"#,
        options: [.caseInsensitive]
    )

    private static let sizePriceRegex = try! NSRegularExpression(
        pattern: #"^(?<name>.+?)\s+(?<portion>\d{1,3}[.,]\d{1,3})\s+(?<price>\d{1,6}(?:[.,]\d{1,2})?)\s*(?<currency>"# + currencyGroup + #")?\.?$"#,
        options: [.caseInsensitive]
    )

    private static let portionRegex = try! NSRegularExpression(
        pattern: #"(?<portion>\d{1,4}(?:[.,]\d{1,3})?\s*(?:кг|гр|мл|г|л|шт|см))\s*\)?$"#,
        options: [.caseInsensitive]
    )

    private static func isPriceOnly(_ text: String) -> Bool {
        priceOnlyRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func capture(
        _ name: String,
        in text: String,
        match: NSTextCheckingResult
    ) -> String? {
        let range = match.range(withName: name)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}
