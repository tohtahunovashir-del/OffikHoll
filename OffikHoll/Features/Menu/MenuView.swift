import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var menu: MenuStore
    @AppStorage("venueName") private var venueName = "OffikHoll"

    @State private var selectedCategoryId: UUID?
    @State private var searchText = ""
    @State private var activeSheet: MenuSheet?
    @State private var showScanner = false
    @State private var shareItem: ShareItem?
    @State private var deleteTarget: DeleteTarget?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    SearchField(placeholder: "Поиск по меню", text: $searchText)
                    categoryChips
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newItem(let categoryId):
                MenuItemEditorView(item: nil, preselectedCategoryId: categoryId)
                    .environmentObject(menu)
            case .editItem(let item):
                MenuItemEditorView(item: item, preselectedCategoryId: item.categoryId)
                    .environmentObject(menu)
            case .newCategory:
                CategoryEditorView(category: nil)
                    .environmentObject(menu)
            case .editCategory(let category):
                CategoryEditorView(category: category)
                    .environmentObject(menu)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            MenuScannerView()
                .environmentObject(menu)
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteTarget
        ) { target in
            Button(deleteButtonTitle(for: target), role: .destructive) {
                performDelete(target)
            }
            Button("Отмена", role: .cancel) {}
        } message: { target in
            Text(deleteMessage(for: target))
        }
        .errorAlert($menu.errorMessage)
        .onChange(of: menu.categories) { categories in
            if let selectedCategoryId,
               !categories.contains(where: { $0.id == selectedCategoryId }) {
                self.selectedCategoryId = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            eyebrow: "\(venueName) · каталог",
            title: "Меню",
            subtitle: "\(menu.items.count) блюд · \(menu.categories.count) категорий"
        ) {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact(.medium)
                    showScanner = true
                } label: {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Palette.gold)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.goldSoft))
                        .overlay(
                            Circle().strokeBorder(Palette.gold.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Сканировать меню")

                Menu {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Сканировать меню", systemImage: "doc.viewfinder")
                    }
                    Button {
                        activeSheet = .newItem(selectedCategoryId ?? menu.categories.first?.id)
                    } label: {
                        Label("Добавить блюдо", systemImage: "plus")
                    }
                    Button {
                        activeSheet = .newCategory
                    } label: {
                        Label("Новая категория", systemImage: "folder.badge.plus")
                    }
                    Divider()
                    Button {
                        exportMenuJSON()
                    } label: {
                        Label("Экспорт меню JSON", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        exportMenuCSV()
                    } label: {
                        Label("Экспорт меню CSV", systemImage: "tablecells")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.surface))
                        .overlay(Circle().strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Действия с меню")
            }
        }
    }

    // MARK: - Categories

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все блюда",
                    count: menu.items.count,
                    isSelected: selectedCategoryId == nil
                ) {
                    selectedCategoryId = nil
                }

                ForEach(menu.categories) { category in
                    FilterChip(
                        title: category.name,
                        count: menu.itemCount(in: category.id),
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
                    }
                    .contextMenu {
                        Button {
                            activeSheet = .editCategory(category)
                        } label: {
                            Label("Переименовать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteTarget = .category(category)
                        } label: {
                            Label("Удалить категорию", systemImage: "trash")
                        }
                    }
                }

                Button {
                    Haptics.selection()
                    activeSheet = .newCategory
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Категория")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(Palette.inkSecondary)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 42)
                    .background(Capsule().fill(Palette.surfaceMuted))
                    .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if menu.items.isEmpty {
            EmptyStateView(
                icon: "doc.viewfinder",
                title: "Меню пока пустое",
                message: "Отсканируйте бумажное меню или добавьте блюда вручную.",
                actionTitle: "Сканировать меню"
            ) {
                showScanner = true
            }
            .premiumCard(padding: 6, cornerRadius: 24)
        } else if isSearching {
            searchResults
        } else if let selectedCategory {
            categorySection(for: selectedCategory, items: menu.items(in: selectedCategory.id))
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(menu.categories) { category in
                    if menu.itemCount(in: category.id) > 0 {
                        categorySection(for: category, items: menu.items(in: category.id))
                    }
                }
                if menu.categories.isEmpty {
                    EmptyStateView(
                        icon: "folder",
                        title: "Нет категорий",
                        message: "Создайте категорию, чтобы сгруппировать блюда.",
                        actionTitle: "Создать категорию"
                    ) {
                        activeSheet = .newCategory
                    }
                    .premiumCard(padding: 6, cornerRadius: 24)
                }
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let results = menu.items
            .filter { $0.searchableText.contains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionLabel(text: "Результаты поиска")
                Spacer()
                Text("\(results.count)")
                    .font(Typeface.number(12, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
            }
            if results.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Ничего не найдено",
                    message: "Попробуйте изменить запрос или добавьте блюдо вручную."
                )
                .premiumCard(padding: 6, cornerRadius: 24)
            } else {
                itemCard(items: results)
            }
        }
    }

    private func categorySection(for category: Category, items: [MenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                IconBadge(icon: category.icon, tint: Palette.gold, size: 30)
                Text(category.name)
                    .font(Typeface.display(19, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text("\(items.count)")
                    .font(Typeface.number(11, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
                Spacer()
                Menu {
                    Button {
                        activeSheet = .editCategory(category)
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    Button {
                        activeSheet = .newItem(category.id)
                    } label: {
                        Label("Добавить блюдо", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        deleteTarget = .category(category)
                    } label: {
                        Label("Удалить категорию", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.inkTertiary)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            if items.isEmpty {
                Text("В этой категории пока нет блюд")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkTertiary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumCard(padding: 0, cornerRadius: 18)
            } else {
                itemCard(items: items)
            }
        }
    }

    private func itemCard(items: [MenuItem]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { item in
                MenuItemRow(
                    item: item,
                    categoryName: menu.categoryName(for: item.categoryId),
                    onEdit: { activeSheet = .editItem(item) },
                    onToggleAvailability: {
                        Haptics.selection()
                        menu.toggleAvailability(item)
                    },
                    onDelete: { deleteTarget = .item(item) }
                )
                if item.id != items.last?.id {
                    Rectangle()
                        .fill(Palette.stroke)
                        .frame(height: 1)
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }

    private var selectedCategory: Category? {
        guard let selectedCategoryId else { return nil }
        return menu.categories.first(where: { $0.id == selectedCategoryId })
    }

    // MARK: - Export

    private func exportMenuJSON() {
        do {
            let url = try BackupService.writeMenuJSON(
                categories: menu.categories,
                items: menu.items
            )
            shareItem = ShareItem(url: url)
        } catch {
            menu.errorMessage = "Не удалось экспортировать меню: \(error.localizedDescription)"
        }
    }

    private func exportMenuCSV() {
        do {
            let url = try BackupService.writeMenuCSV(
                categories: menu.categories,
                items: menu.items
            )
            shareItem = ShareItem(url: url)
        } catch {
            menu.errorMessage = "Не удалось экспортировать меню: \(error.localizedDescription)"
        }
    }

    // MARK: - Deleting

    private var deleteTitle: String {
        switch deleteTarget {
        case .item: return "Удалить блюдо?"
        case .category: return "Удалить категорию?"
        case .none: return "Удалить?"
        }
    }

    private func deleteButtonTitle(for target: DeleteTarget) -> String {
        switch target {
        case .item: return "Удалить блюдо"
        case .category: return "Удалить категорию"
        }
    }

    private func deleteMessage(for target: DeleteTarget) -> String {
        switch target {
        case .item(let item):
            return "«\(item.name)» исчезнет из меню. Уже открытые заказы сохранят эту позицию."
        case .category(let category):
            let count = menu.itemCount(in: category.id)
            return count > 0
                ? "Вместе с категорией «\(category.name)» будут удалены \(count) блюд."
                : "Категория «\(category.name)» будет удалена."
        }
    }

    private func performDelete(_ target: DeleteTarget) {
        switch target {
        case .item(let item):
            menu.deleteItem(item)
        case .category(let category):
            menu.deleteCategory(category)
        }
        Haptics.warning()
        deleteTarget = nil
    }
}

// MARK: - Helpers

enum MenuSheet: Identifiable {
    case newItem(UUID?)
    case editItem(MenuItem)
    case newCategory
    case editCategory(Category)

    var id: String {
        switch self {
        case .newItem: return "new-item"
        case .editItem(let item): return "edit-item-\(item.id.uuidString)"
        case .newCategory: return "new-category"
        case .editCategory(let category): return "edit-category-\(category.id.uuidString)"
        }
    }
}

enum DeleteTarget: Identifiable {
    case item(MenuItem)
    case category(Category)

    var id: String {
        switch self {
        case .item(let item): return "item-\(item.id.uuidString)"
        case .category(let category): return "category-\(category.id.uuidString)"
        }
    }
}

struct MenuItemRow: View {
    let item: MenuItem
    let categoryName: String
    let onEdit: () -> Void
    let onToggleAvailability: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                icon: CategoryIcons.icon(forCategoryNamed: categoryName),
                tint: item.isAvailable ? Palette.gold : Palette.inkTertiary,
                size: 42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if !item.details.isEmpty {
                        Text(item.details)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Palette.inkTertiary)
                            .lineLimit(1)
                    }
                    if !item.isAvailable {
                        Text("СТОП-ЛИСТ")
                            .font(.system(size: 8, weight: .bold))
                            .kerning(0.5)
                            .foregroundColor(Palette.danger)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.dangerSoft))
                    }
                }
            }

            Spacer(minLength: 4)

            Text(Price.string(item.price))
                .font(Typeface.number(14, weight: .semibold))
                .foregroundColor(Palette.ink)
                .lineLimit(1)

            Menu {
                Button(action: onEdit) {
                    Label("Редактировать", systemImage: "pencil")
                }
                Button(action: onToggleAvailability) {
                    Label(
                        item.isAvailable ? "В стоп-лист" : "Вернуть в меню",
                        systemImage: item.isAvailable ? "pause.circle" : "play.circle"
                    )
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .opacity(item.isAvailable ? 1 : 0.65)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Редактировать"), onEdit)
    }
}
