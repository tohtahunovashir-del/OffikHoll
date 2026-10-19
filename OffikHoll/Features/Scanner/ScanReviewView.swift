import SwiftUI

/// Stage 4 of the pipeline: interactive confirmation. Nothing reaches the
/// database until the waiter taps «Добавить в меню»; every name, price and
/// category stays editable, and unchecked rows are ignored.
struct ScanReviewView: View {
    @EnvironmentObject private var menu: MenuStore

    @Binding var drafts: [ScanDraft]
    let onBack: () -> Void
    let onImported: (MenuImportResult) -> Void

    private let importer = MenuImportService()

    @State private var filter: ReviewFilter = .all
    @State private var searchText = ""
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var didApplyDuplicateMarks = false

    private enum ReviewFilter: String, CaseIterable {
        case all = "Все"
        case selected = "Выбрано"
        case attention = "Проверить"
    }

    // MARK: - Derived state

    private var includedCount: Int {
        drafts.filter { $0.isIncluded && $0.isValid }.count
    }

    private var includedTotal: Double {
        drafts.filter { $0.isIncluded }.reduce(0) { $0 + ($1.price ?? 0) }
    }

    private var duplicateIDs: Set<UUID> {
        importer.duplicateIDs(in: drafts)
    }

    private var lowConfidenceCount: Int {
        importer.lowConfidenceCount(in: drafts)
    }

    private var categoryOptions: [String] {
        importer.categorySuggestions(for: drafts, existing: menu.categories)
    }

    private var scannedCurrencies: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for draft in drafts {
            let currency = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currency.isEmpty, currency != "₽", !seen.contains(currency) else { continue }
            seen.insert(currency)
            result.append(currency)
        }
        return result
    }

    private var visibleIDs: [UUID] {
        var ids = drafts.map(\.id)
        switch filter {
        case .all:
            break
        case .selected:
            ids = drafts.filter { $0.isIncluded }.map(\.id)
        case .attention:
            let duplicates = duplicateIDs
            ids = drafts.filter {
                $0.confidence < 0.55 || !$0.isValid || duplicates.contains($0.id)
            }.map(\.id)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let matching = Set(
                drafts.filter {
                    $0.name.localizedCaseInsensitiveContains(query)
                        || $0.categoryName.localizedCaseInsensitiveContains(query)
                }.map(\.id)
            )
            ids = ids.filter { matching.contains($0) }
        }
        return ids
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                summaryCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        chipRow

                        SearchField(
                            placeholder: "Поиск по названию или категории",
                            text: $searchText
                        )
                        .padding(.bottom, 2)

                        if scannedCurrencies.isEmpty == false {
                            currencyNote
                        }

                        if visibleIDs.isEmpty {
                            EmptyStateView(
                                icon: "text.magnifyingglass",
                                title: "Ничего не найдено",
                                message: "Измените фильтр или поисковый запрос. Распознанные строки останутся в списке."
                            )
                            .padding(.top, 20)
                        } else {
                            ForEach(visibleIDs, id: \.self) { id in
                                if let index = drafts.firstIndex(where: { $0.id == id }) {
                                    ScanDraftRow(
                                        draft: $drafts[index],
                                        categories: categoryOptions,
                                        isDuplicate: duplicateIDs.contains(id),
                                        onDelete: { removeDraft(id: id) }
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                }
                            }

                            addRowButton
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
                .safeAreaInset(edge: .bottom) {
                    bottomBar
                }
            }
        }
        .onAppear(perform: applyDuplicateMarks)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .errorAlert(
            Binding<String?>(
                get: { exportError ?? menu.errorMessage },
                set: { value in
                    if value == nil {
                        exportError = nil
                        menu.errorMessage = nil
                    }
                }
            )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            CircleIconButton(icon: "chevron.left", accessibilityTitle: "Назад к сканированию") {
                onBack()
            }

            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "Сканирование меню")
                Text("Проверьте блюда")
                    .font(Typeface.display(27, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 6)

            Menu {
                Button {
                    exportDrafts(asJSON: true)
                } label: {
                    Label("Экспорт JSON", systemImage: "curlybraces")
                }
                Button {
                    exportDrafts(asJSON: false)
                } label: {
                    Label("Экспорт CSV", systemImage: "tablecells")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Экспорт распознанного меню")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                StatBlock(title: "Найдено", value: "\(drafts.count)")
                Spacer(minLength: 8)
                verticalRule
                Spacer(minLength: 8)
                StatBlock(title: "Выбрано", value: "\(includedCount)", tint: Palette.accent)
                Spacer(minLength: 8)
                verticalRule
                Spacer(minLength: 8)
                StatBlock(
                    title: "Сумма",
                    value: Price.compact(includedTotal),
                    tint: Palette.gold,
                    alignment: .trailing
                )
            }

            if lowConfidenceCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.gold)
                    Text("\(lowConfidenceCount) \(AppFormat.plural(lowConfidenceCount, "строка требует", "строки требуют", "строк требуют")) проверки — отмечены точкой.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .premiumCard()
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1, height: 30)
    }

    // MARK: - Filters

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReviewFilter.allCases, id: \.self) { item in
                    FilterChip(
                        title: item.rawValue,
                        count: count(for: item),
                        isSelected: filter == item
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            filter = item
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 2)
    }

    private func count(for filter: ReviewFilter) -> Int {
        switch filter {
        case .all:
            return drafts.count
        case .selected:
            return drafts.filter { $0.isIncluded }.count
        case .attention:
            let duplicates = duplicateIDs
            return drafts.filter {
                $0.confidence < 0.55 || !$0.isValid || duplicates.contains($0.id)
            }.count
        }
    }

    private var currencyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.inkSecondary)
            Text("В меню обнаружены цены в \(scannedCurrencies.joined(separator: ", ")). Они будут добавлены в рублях без пересчёта — проверьте суммы.")
                .font(.system(size: 11.5))
                .foregroundColor(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.goldSoft)
        )
    }

    // MARK: - Secondary actions

    private var addRowButton: some View {
        Button {
            let category = importer.scannedCategoryNames(in: drafts).first ?? "Разное"
            withAnimation(.easeOut(duration: 0.18)) {
                drafts.append(
                    ScanDraft(
                        name: "",
                        priceText: "",
                        categoryName: category,
                        confidence: 1,
                        isIncluded: true
                    )
                )
            }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Добавить блюдо вручную")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Palette.stroke,
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    let allSelected = includedCount == drafts.count
                    withAnimation(.easeOut(duration: 0.16)) {
                        for index in drafts.indices {
                            drafts[index].isIncluded = !allSelected
                        }
                    }
                    Haptics.selection()
                } label: {
                    Text(includedCount == drafts.count ? "Снять все" : "Выбрать все")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Palette.inkSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(AppFormat.items(includedCount))
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkTertiary)
                    Text(Price.string(includedTotal))
                        .font(Typeface.number(18, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
            }

            Button {
                performImport()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(includedCount > 0
                         ? "Добавить в меню · \(includedCount)"
                         : "Добавить в меню")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(includedCount == 0)
            .opacity(includedCount == 0 ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Palette.surface
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Palette.stroke)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func applyDuplicateMarks() {
        guard !didApplyDuplicateMarks else { return }
        didApplyDuplicateMarks = true
        let duplicates = duplicateIDs
        guard !duplicates.isEmpty else { return }
        for index in drafts.indices where duplicates.contains(drafts[index].id) {
            drafts[index].isIncluded = false
        }
    }

    private func removeDraft(id: UUID) {
        withAnimation(.easeOut(duration: 0.18)) {
            drafts.removeAll { $0.id == id }
        }
        Haptics.impact(.light)
    }

    private func performImport() {
        let prepared = importer.prepare(drafts)
        guard !prepared.drafts.isEmpty else {
            exportError = "Нет корректных позиций: проверьте названия и цены."
            Haptics.error()
            return
        }
        guard let result = menu.importMenuItems(
            prepared.drafts,
            createMissingCategories: true,
            skipDuplicates: true
        ) else {
            Haptics.error()
            return
        }
        Haptics.success()
        onImported(result)
    }

    private func exportDrafts(asJSON: Bool) {
        do {
            let url = try asJSON
                ? BackupService.writeScanDraftsJSON(drafts)
                : BackupService.writeScanDraftsCSV(drafts)
            shareItem = ShareItem(url: url)
        } catch {
            exportError = "Не удалось подготовить файл: \(error.localizedDescription)"
        }
    }
}

// MARK: - Row

private struct ScanDraftRow: View {
    @Binding var draft: ScanDraft
    let categories: [String]
    let isDuplicate: Bool
    let onDelete: () -> Void

    private var isValid: Bool { draft.isValid }

    private var confidenceTint: Color {
        switch draft.confidenceLevel {
        case 2: return Palette.accent
        case 1: return Palette.gold
        default: return Palette.danger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.14)) {
                    draft.isIncluded.toggle()
                }
                Haptics.selection()
            } label: {
                ZStack {
                    Circle()
                        .fill(draft.isIncluded ? Palette.accentFill : Color.clear)
                        .frame(width: 26, height: 26)
                    Circle()
                        .strokeBorder(
                            draft.isIncluded ? Palette.accentFill : Palette.strokeStrong,
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if draft.isIncluded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.isIncluded ? "Убрать из импорта" : "Добавить в импорт")

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Название блюда", text: $draft.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)

                    if isDuplicate {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Palette.gold)
                            .accessibilityLabel("Дубликат")
                    }

                    Circle()
                        .fill(confidenceTint)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel("Уверенность распознавания \(Int(draft.confidence * 100)) процентов")
                }

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        TextField("Цена", text: $draft.priceText)
                            .font(Typeface.number(15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 66)
                        Text(draft.currency.isEmpty ? "₽" : draft.currency)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Palette.inkTertiary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Palette.surfaceMuted)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isValid ? Color.clear : Palette.danger.opacity(0.5), lineWidth: 1)
                    )

                    Menu {
                        ForEach(categories, id: \.self) { name in
                            Button {
                                draft.categoryName = name
                                Haptics.selection()
                            } label: {
                                if name == draft.categoryName {
                                    Label(name, systemImage: "checkmark")
                                } else {
                                    Text(name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 10, weight: .semibold))
                            Text(draft.categoryName.isEmpty ? "Разное" : draft.categoryName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Palette.inkTertiary)
                        }
                        .foregroundColor(Palette.inkSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(
                            Capsule().fill(Palette.surfaceMuted)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Palette.inkTertiary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Palette.surfaceMuted))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Удалить строку")
                }
            }
            .padding(.top, 4)
            .padding(.trailing, 6)
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    draft.isIncluded ? Palette.stroke : Palette.stroke.opacity(0.5),
                    lineWidth: 1
                )
        )
        .shadow(color: Palette.shadow.opacity(0.04), radius: 8, x: 0, y: 4)
        .opacity(draft.isIncluded ? 1 : 0.62)
        .animation(.easeOut(duration: 0.16), value: draft.isIncluded)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить строку", systemImage: "trash")
            }
            Button {
                draft.isIncluded.toggle()
                Haptics.selection()
            } label: {
                Label(
                    draft.isIncluded ? "Не добавлять" : "Добавить",
                    systemImage: draft.isIncluded ? "xmark.circle" : "checkmark.circle"
                )
            }
        }
    }
}
