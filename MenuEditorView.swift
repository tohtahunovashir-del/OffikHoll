import SwiftUI

private enum MenuEditorSheet: Identifiable {
    case newItem(UUID?)
    case editItem(MenuItem)
    case newCategory
    case editCategory(Category)
    case scanner
    case export(URL)

    var id: String {
        switch self {
        case .newItem(_): return "newItem"
        case .editItem(let item): return "editItem-\(item.id)"
        case .newCategory: return "newCategory"
        case .editCategory(let category): return "editCategory-\(category.id)"
        case .scanner: return "scanner"
        case .export(let url): return "export-\(url.absoluteString)"
        }
    }
}

struct MenuEditorView: View {
    @EnvironmentObject private var store: RestaurantStore
    @State private var selectedCategoryID: UUID?
    @State private var activeSheet: MenuEditorSheet?
    @State private var exportError: String?

    private var selectedCategory: Category? {
        store.categories.first(where: { $0.id == selectedCategoryID }) ?? store.categories.first
    }
    private var visibleItems: [MenuItem] {
        guard let category = selectedCategory else { return store.menuItems }
        return store.menuItems.filter { $0.categoryId == category.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker
                if visibleItems.isEmpty {
                    EmptyStateView(title: "Добавьте первое блюдо", subtitle: "Создайте меню вручную или распознайте его по фотографии", symbol: "menucard")
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(visibleItems) { item in
                            Button { activeSheet = .editItem(item) } label: {
                                HStack(spacing: 13) {
                                    RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 42, height: 42)
                                        .overlay(Image(systemName: "fork.knife").foregroundStyle(Color.accentColor))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(store.categories.first(where: { $0.id == item.categoryId })?.name ?? "Без категории")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.price.formatted(.number.precision(.fractionLength(0...2))) + " ₽")
                                        .font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                            .swipeActions {
                                Button(role: .destructive) { store.deleteMenuItem(item) } label: { Label("Удалить", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Меню")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button { activeSheet = .scanner } label: { Label("Сканировать меню", systemImage: "viewfinder") }
                        Button { activeSheet = .newCategory } label: { Label("Новая категория", systemImage: "folder.badge.plus") }
                        Button { activeSheet = .newItem(selectedCategory?.id) } label: { Label("Новое блюдо", systemImage: "plus") }
                        Divider()
                        Button { makeExport("json") } label: { Label("Экспорт JSON", systemImage: "square.and.arrow.up") }
                        Button { makeExport("csv") } label: { Label("Экспорт CSV", systemImage: "tablecells") }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3)
                    }
                    .accessibilityLabel("Действия с меню")
                }
            }
            .onAppear { if selectedCategoryID == nil { selectedCategoryID = store.categories.first?.id } }
            .onChange(of: store.categories) { categories in
                if !categories.contains(where: { $0.id == selectedCategoryID }) { selectedCategoryID = categories.first?.id }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newItem(let categoryID):
                    MenuItemForm(categories: store.categories, initialCategoryID: categoryID) { name, price, id in
                        store.saveMenuItem(name: name, price: price, categoryID: id)
                    }
                case .editItem(let item):
                    MenuItemForm(categories: store.categories, item: item) { name, price, id in
                        store.saveMenuItem(name: name, price: price, categoryID: id, editing: item)
                    }
                case .newCategory:
                    CategoryForm { store.saveCategory(name: $0) }
                case .editCategory(let category):
                    CategoryForm(category: category) { store.saveCategory(name: $0, editing: category) }
                case .scanner:
                    NavigationStack { MenuScannerView() }
                        .environmentObject(store)
                case .export(let url):
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Не удалось экспортировать меню", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("Понятно", role: .cancel) { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(store.categories) { category in
                    let selected = selectedCategory?.id == category.id
                    Button { selectedCategoryID = category.id } label: {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .padding(.horizontal, 15).frame(height: 42)
                            .background(selected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { activeSheet = .editCategory(category) } label: { Label("Изменить категорию", systemImage: "pencil") }
                        Button(role: .destructive) { store.deleteCategory(category) } label: { Label("Удалить категорию", systemImage: "trash") }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private func makeExport(_ format: String) {
        do { activeSheet = .export(try store.exportMenu(format: format)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct MenuItemForm: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let onSave: (String, Double, UUID) -> Void
    @State private var name: String
    @State private var price: Double
    @State private var categoryID: UUID?

    init(categories: [Category], item: MenuItem? = nil, initialCategoryID: UUID? = nil, onSave: @escaping (String, Double, UUID) -> Void) {
        self.categories = categories
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _price = State(initialValue: item?.price ?? 0)
        _categoryID = State(initialValue: item?.categoryId ?? initialCategoryID ?? categories.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    TextField("Название", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Цена, ₽", value: $price, format: .number)
                        .keyboardType(.decimalPad)
                    if !categories.isEmpty {
                        Picker("Категория", selection: $categoryID) {
                            ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
                        }
                    }
                }
            }
            .navigationTitle(name.isEmpty ? "Новое блюдо" : "Изменить блюдо")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        guard let categoryID else { return }
                        onSave(name, price, categoryID)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || price <= 0 || categoryID == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CategoryForm: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var name: String

    init(category: Category? = nil, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form { TextField("Название категории", text: $name).textInputAutocapitalization(.words) }
                .navigationTitle("Категория")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Сохранить") { onSave(name); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(Color.accentColor)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .padding(28)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
