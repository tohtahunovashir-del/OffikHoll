import Combine
import Foundation
import UIKit

/// Черновик распознанного блюда для экрана проверки.
struct ScanDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var priceText: String
    var categoryName: String
    var confidence: Double
    var isIncluded: Bool
    var isDuplicate: Bool

    init(
        id: UUID = UUID(),
        name: String,
        priceText: String,
        categoryName: String,
        confidence: Double,
        isIncluded: Bool = true,
        isDuplicate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.priceText = priceText
        self.categoryName = categoryName
        self.confidence = confidence
        self.isIncluded = isIncluded
        self.isDuplicate = isDuplicate
    }

    init(dish: ParsedDish) {
        self.init(
            name: dish.name,
            priceText: PriceParser.editable(dish.price),
            categoryName: dish.category,
            confidence: dish.confidence
        )
    }

    var priceValue: Double? {
        PriceParser.value(from: priceText)
    }

    var isValid: Bool {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return false }
        guard let price = priceValue else { return false }
        return price >= Constants.ocrMinimumPrice && price <= Constants.ocrMaximumPrice
    }

    var needsAttention: Bool {
        confidence < 0.55 || !isValid || isDuplicate
    }
}

final class ScannerViewModel: ObservableObject {
    @Published var drafts: [ScanDraft] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published var errorMessage: String?
    @Published private(set) var showReview = false

    private let ocrService: OCRService
    private let menuRepository: MenuRepository
    private var runID = UUID()

    init(
        ocrService: OCRService = OCRService.shared,
        menuRepository: MenuRepository = AppDependencies.shared.menuRepository
    ) {
        self.ocrService = ocrService
        self.menuRepository = menuRepository
    }

    // MARK: - Derived

    var includedCount: Int {
        drafts.filter { $0.isIncluded && $0.isValid }.count
    }

    var attentionCount: Int {
        drafts.filter { $0.needsAttention }.count
    }

    var canImport: Bool {
        includedCount > 0 && !isProcessing
    }

    // MARK: - Recognition

    func process(image: UIImage) {
        isProcessing = true
        progress = 0.08
        errorMessage = nil
        showReview = false

        let currentRun = UUID()
        runID = currentRun

        let vocabulary = (try? menuRepository.vocabulary()) ?? []
        let categories = (try? menuRepository.categoryNames()) ?? []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let dishes = try self.ocrService.recognizeMenu(
                    in: image,
                    customWords: vocabulary,
                    knownCategories: categories
                )
                DispatchQueue.main.async {
                    guard self.runID == currentRun else { return }
                    self.append(dishes)
                    self.isProcessing = false
                    self.progress = 1
                    self.showReview = !self.drafts.isEmpty
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.runID == currentRun else { return }
                    self.isProcessing = false
                    self.progress = 0
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func append(_ dishes: [ParsedDish]) {
        var known = Set(drafts.map { MenuRepository.normalized($0.name) })
        for dish in dishes {
            var draft = ScanDraft(dish: dish)
            let key = MenuRepository.normalized(dish.name)
            if known.contains(key) {
                draft.isDuplicate = true
                draft.isIncluded = false
            } else {
                known.insert(key)
            }
            drafts.append(draft)
        }
        if drafts.isEmpty {
            errorMessage = OCRError.noText.localizedDescription
        }
    }

    // MARK: - Editing

    func toggle(_ draft: ScanDraft) {
        guard let index = drafts.firstIndex(where: { $0.id == draft.id }) else { return }
        drafts[index].isIncluded.toggle()
        HapticsService.selection()
    }

    func remove(_ draft: ScanDraft) {
        drafts.removeAll { $0.id == draft.id }
        if drafts.isEmpty {
            showReview = false
        }
    }

    func includeAll() {
        for index in drafts.indices {
            drafts[index].isIncluded = !drafts[index].isDuplicate && drafts[index].isValid
        }
    }

    // MARK: - Import

    @discardableResult
    func importSelected(into viewModel: MenuEditorViewModel) -> Int {
        let included = drafts.filter { $0.isIncluded && $0.isValid }
        guard !included.isEmpty else {
            errorMessage = "Отметьте хотя бы одно блюдо с названием и ценой."
            return 0
        }

        let dishes: [ParsedDish] = included.compactMap { draft in
            guard let price = draft.priceValue else { return nil }
            let category = draft.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedDish(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                price: price,
                category: category.isEmpty ? Constants.defaultCategoryName : category,
                confidence: draft.confidence
            )
        }

        let inserted = viewModel.importDishes(dishes)
        if inserted > 0 {
            reset()
        }
        return inserted
    }

    func reset() {
        drafts = []
        showReview = false
        isProcessing = false
        progress = 0
        errorMessage = nil
    }
}
