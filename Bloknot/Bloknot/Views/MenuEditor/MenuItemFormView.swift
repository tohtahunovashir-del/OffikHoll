import Foundation
import SwiftUI

struct MenuItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let onSave: (String, String, UUID) -> Void

    @State private var name = ""
    @State private var priceText = ""
    @State private var categoryId: UUID

    init(
        categories: [Category],
        category: Category,
        onSave: @escaping (String, String, UUID) -> Void
    ) {
        self.categories = categories
        self.onSave = onSave
        _categoryId = State(initialValue: category.id)
    }

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && PriceParser.value(from: priceText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Блюдо") {
                    TextField("Название", text: $name)
                        .font(.system(size: 15))
                    TextField("Цена, ₽", text: $priceText)
                        .font(.system(size: 15))
                        .keyboardType(.decimalPad)

                    Picker("Категория", selection: $categoryId) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .font(.system(size: 15))
                }
            }
            .navigationTitle("Новое блюдо")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(name, priceText, categoryId)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
