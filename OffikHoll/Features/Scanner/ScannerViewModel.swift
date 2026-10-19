import Foundation
import Combine
import UIKit

struct ScannedPage: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

/// Drives the scan flow: pages -> Vision OCR -> parser -> editable drafts.
/// The class is intentionally not `@MainActor` so it can be created from a
/// SwiftUI view initializer; every `@Published` update inside async work is
/// pushed through `MainActor.run`.
final class ScannerViewModel: ObservableObject {
    enum Stage: Equatable {
        case capture
        case processing
        case review
    }

    @Published var stage: Stage = .capture
    @Published var pages: [ScannedPage] = []
    @Published var drafts: [ScanDraft] = []
    @Published var stageTitle = ""
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let ocrService = MenuOCRService()
    private var runID = UUID()

    func addPage(_ image: UIImage, title: String? = nil) {
        let label = title ?? "Страница \(pages.count + 1)"
        pages.append(ScannedPage(image: image, title: label))
    }

    func removePage(id: UUID) {
        pages.removeAll { $0.id == id }
    }

    func reset() {
        runID = UUID()
        pages = []
        drafts = []
        stage = .capture
        progress = 0
        stageTitle = ""
        isProcessing = false
    }

    /// Leaves the processing screen immediately. Any still-running OCR task
    /// becomes stale because its `runID` no longer matches.
    func cancelRecognition() {
        runID = UUID()
        isProcessing = false
        progress = 0
        stageTitle = ""
        stage = .capture
    }

    func recognize(existingCategories: [String], customWords: [String]) async {
        guard !pages.isEmpty, !isProcessing else { return }
        let images = pages.map(\.image)
        let token = UUID()
        runID = token

        await MainActor.run {
            isProcessing = true
            stage = .processing
            stageTitle = "Подготовка изображений"
            progress = 0.02
            drafts = []
        }

        do {
            var allLines: [RecognizedLine] = []
            let total = max(Double(images.count), 1)

            for (index, image) in images.enumerated() {
                let stillCurrent = await MainActor.run { self.runID == token }
                guard stillCurrent else { return }
                await MainActor.run {
                    stageTitle = "Распознаём страницу \(index + 1) из \(images.count)"
                    progress = 0.05 + 0.70 * Double(index) / total
                }
                let lines = try await ocrService.recognizeLines(
                    in: image,
                    pageIndex: index,
                    customWords: customWords
                )
                allLines.append(contentsOf: lines)
                await MainActor.run {
                    progress = 0.05 + 0.70 * Double(index + 1) / total
                }
            }

            let stillCurrent = await MainActor.run { self.runID == token }
            guard stillCurrent else { return }
            await MainActor.run {
                stageTitle = "Анализируем и структурируем меню"
                progress = 0.92
            }
            let parsed = MenuParser().parse(
                lines: allLines,
                existingCategories: existingCategories
            )
            let mapped = parsed.map { ScanDraft(parsed: $0) }

            await MainActor.run {
                guard self.runID == token else { return }
                drafts = mapped
                progress = 1
                isProcessing = false
                if mapped.isEmpty {
                    stage = .capture
                    errorMessage = "Не удалось найти блюда с ценами. Попробуйте более чёткое фото, добавьте страницу или вставьте текст вручную."
                } else {
                    stage = .review
                    Haptics.success()
                }
            }
        } catch {
            await MainActor.run {
                guard self.runID == token else { return }
                isProcessing = false
                stage = .capture
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "Ошибка распознавания: \(error.localizedDescription)"
            }
        }
    }

    func parsePastedText(_ text: String, existingCategories: [String]) {
        let parsed = MenuParser().parse(text: text, existingCategories: existingCategories)
        drafts = parsed.map { ScanDraft(parsed: $0) }
        if parsed.isEmpty {
            errorMessage = "В тексте не найдены блюда с ценами. Формат: «Название... 450»."
        } else {
            progress = 1
            stage = .review
            Haptics.success()
        }
    }

    func includedCount() -> Int {
        drafts.filter { $0.isIncluded }.count
    }

    func includedTotal() -> Double {
        drafts.filter { $0.isIncluded }.reduce(0) { $0 + ($1.price ?? 0) }
    }

    func selectAll(_ included: Bool) {
        for index in drafts.indices {
            drafts[index].isIncluded = included
        }
        Haptics.selection()
    }
}
