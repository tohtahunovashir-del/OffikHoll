import Foundation
import SwiftUI

/// Одна точка презентации: SwiftUI надёжно показывает только один sheet
/// с одного уровня иерархии, поэтому сканер и форма категории идут через enum.
private enum MenuEditorSheet: String, Identifiable {
    case scanner
    case newCategory

    var id: String { rawValue }
}

struct MenuEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MenuEditorViewModel()
    @State private var activeSheet: MenuEditorSheet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.categories) { category in
                        NavigationLink {
                            CategoryListView(viewModel: viewModel, category: category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Theme.accentSoft)
                                    )

                                Text(category.name)
                                    .font(.system(size: 15, weight: .medium))

                                Spacer(minLength: 4)

                                Text("\(viewModel.items(in: category.id).count)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.inkSecondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteCategories)
                } header: {
                    Text("Категории")
                } footer: {
                    Text("\(Plural.items(viewModel.catalog.items.count)) в меню. Свайп влево удаляет категорию вместе с блюдами.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Меню")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .newCategory
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    activeSheet = .scanner
                } label: {
                    Label("Сканировать меню", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Constants.screenPadding)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.96))
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .scanner:
                    ScannerView(editor: viewModel)
                case .newCategory:
                    CategoryFormView { name in
                        viewModel.addCategory(name)
                    }
                }
            }
            .alert("Ошибка", isPresented: errorBinding) {
                Button("Понятно", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }

    private func deleteCategories(at offsets: IndexSet) {
        let categories = viewModel.categories
        for index in offsets where index < categories.count {
            viewModel.deleteCategory(categories[index])
        }
    }
}


// MARK: - Новая категория

private struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String) -> Void

    @State private var name = ""

    init(onSave: @escaping (String) -> Void) {
        self.onSave = onSave
    }

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например: «Коктейли»", text: $name)
                        .font(.system(size: 15))
                }

                Section {
                    Text("Категория появится в меню сразу после сохранения. Блюда добавляются внутри категории.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.inkSecondary)
                }
            }
            .navigationTitle("Новая категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
