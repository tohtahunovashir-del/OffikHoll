import Foundation

/// Bridges the editable OCR review rows to the menu store.
///
/// Responsibilities kept out of the view:
/// - normalisation of names/categories for duplicate detection;
/// - detection of repeated rows inside one scanning session;
/// - composition of the `details` string;
/// - skipping rows the waiter unchecked or that are still invalid.
struct MenuImportService {
    struct PreparedImport {
        var drafts: [MenuItemDraft]
        var uncheckedRows: Int
        var invalidRows: Int
        var duplicates: Int

        var isEmpty: Bool { drafts.isEmpty }
    }

    // MARK: - Preparation

    func prepare(_ rows: [ScanDraft]) -> PreparedImport {
        var prepared: [MenuItemDraft] = []
        var seen = Set<String>()
        var unchecked = 0
        var invalid = 0
        var duplicates = 0

        for row in rows {
            guard row.isIncluded else {
                unchecked += 1
                continue
            }
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= 2, let price = row.price, price > 0 else {
                invalid += 1
                continue
            }
            let category = normalizedCategory(row.categoryName)
            let key = "\(normalizedKey(category))|\(normalizedKey(name))"
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)

            prepared.append(
                MenuItemDraft(
                    name: name,
                    price: price,
                    categoryName: category,
                    details: details(for: row)
                )
            )
        }

        return PreparedImport(
            drafts: prepared,
            uncheckedRows: unchecked,
            invalidRows: invalid,
            duplicates: duplicates
        )
    }

    // MARK: - Duplicates inside the scan

    /// IDs of rows that repeat an earlier row of the same category, so the
    /// review screen can warn the waiter and uncheck them by default.
    func duplicateIDs(in rows: [ScanDraft]) -> Set<UUID> {
        var seen = Set<String>()
        var duplicates = Set<UUID>()
        for row in rows {
            let name = normalizedKey(row.name)
            guard !name.isEmpty else { continue }
            let key = "\(normalizedKey(normalizedCategory(row.categoryName)))|\(name)"
            if seen.contains(key) {
                duplicates.insert(row.id)
            } else {
                seen.insert(key)
            }
        }
        return duplicates
    }

    /// Suggests previously used categories matching the scanned ones, so the
    /// waiter can keep their own category naming instead of creating twins.
    func categorySuggestions(for rows: [ScanDraft], existing: [Category]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for category in existing {
            let key = normalizedKey(category.name)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(category.name)
        }
        for row in rows {
            let name = normalizedCategory(row.categoryName)
            let key = normalizedKey(name)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name)
        }
        if !seen.contains(normalizedKey("Разное")) {
            result.append("Разное")
        }
        return result
    }

    func scannedCategoryNames(in rows: [ScanDraft]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for row in rows {
            let name = normalizedCategory(row.categoryName)
            let key = normalizedKey(name)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name)
        }
        return result
    }

    func lowConfidenceCount(in rows: [ScanDraft]) -> Int {
        rows.filter { $0.confidence < 0.55 }.count
    }

    // MARK: - Helpers

    func details(for row: ScanDraft) -> String {
        let portion = row.portion.trimmingCharacters(in: .whitespacesAndNewlines)
        return portion.isEmpty ? "" : "Порция: \(portion)"
    }

    func normalizedCategory(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Разное" : trimmed
    }

    func normalizedKey(_ raw: String) -> String {
        var value = raw.lowercased()
        value = value.replacingOccurrences(of: "ё", with: "е")
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        value = String(value.unicodeScalars.filter { allowed.contains($0) })
        let parts = value.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }
}
