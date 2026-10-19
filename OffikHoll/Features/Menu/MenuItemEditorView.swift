import SwiftUI

struct MenuItemEditorView: View {
    @EnvironmentObject private var menu: MenuStore
    @Environment(\.dismiss) private var dismiss

    private let item: MenuItem?
    private let preselectedCategoryId: UUID?

    @State private var name: String
    @State private var priceText: String
    @State private var details: String
    @State private var categoryId: UUID?
    @State private var isAvailable: Bool
    @State private var showDeleteConfirm = false
    @FocusState private var nameFocused: Bool

    init(item: MenuItem?, preselectedCategoryId: UUID?) {
        self.item = item
        self.preselectedCategoryId = preselectedCategoryId
        _name = State(initialValue: item?.name ?? "")
        _priceText = State(initialValue: item.map { PriceParser.editable($0.price) } ?? "")
        _details = State(initialValue: item?.details ?? "")
        _categoryId = State(initialValue: item?.categoryId ?? preselectedCategoryId)
        _isAvailable = State(initialValue: item?.isAvailable ?? true)
    }

    private var isEditing: Bool { item != nil }

    private var selectedCategory: Category? {
        menu.categories.first(where: { $0.id == categoryId })
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    fieldBlock("Название") {
                        TextField("Например: Цезарь с курицей", text: $name)
                            .focused($nameFocused)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                    }

                    fieldBlock("Цена") {
                        HStack(spacing: 6) {
                            TextField("0", text: $priceText)
                                .keyboardType(.decimalPad)
                                .font(Typeface.number(20, weight: .semibold))
                            Text(Price.currency)
                                .font(Typeface.number(16, weight: .medium))
                                .foregroundColor(Palette.inkSecondary)
                        }
                    }

                    fieldBlock("Категория") {
                        categoryMenu
                    }

                    fieldBlock("Описание и порция") {
                        TextField("Например: 220 г · без лука", text: $details, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    HStack(spacing: 12) {
                        IconBadge(icon: "checkmark.circle", tint: Palette.accent, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("В наличии")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Palette.ink)
                            Text("Блюдо доступно для заказа")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.inkSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $isAvailable)
                            .labelsHidden()
                            .tint(Palette.accent)
                    }
                    .premiumCard(padding: 12, cornerRadius: 16)

                    Button {
                        save()
                    } label: {
                        Text(isEditing ? "Сохранить изменения" : "Добавить в меню")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)

                    if isEditing {
                        Button("Удалить блюдо") {
                            showDeleteConfirm = true
                        }
                        .buttonStyle(DestructiveButtonStyle(compact: true))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if categoryId == nil {
                categoryId = menu.categories.first?.id
            }
            if !isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    nameFocused = true
                }
            }
        }
        .confirmationDialog(
            "Удалить блюдо?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let item {
                    menu.deleteItem(item)
                    Haptics.warning()
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("«\(item?.name ?? "Блюдо")» исчезнет из меню. Открытые заказы сохранят позицию.")
        }
        .errorAlert($menu.errorMessage)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isEditing ? "РЕДАКТИРОВАНИЕ" : "НОВОЕ БЛЮДО")
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(1.4)
                    .foregroundColor(Palette.gold)
                Text(isEditing ? "Блюдо" : "Добавить блюдо")
                    .font(Typeface.display(27, weight: .semibold))
                    .foregroundColor(Palette.ink)
            }
            Spacer(minLength: 4)
            CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть") {
                dismiss()
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            if menu.categories.isEmpty {
                Text("Сначала создайте категорию")
            } else {
                ForEach(menu.categories) { category in
                    Button {
                        categoryId = category.id
                        Haptics.selection()
                    } label: {
                        Label(
                            category.name,
                            systemImage: categoryId == category.id ? "checkmark" : category.icon
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedCategory?.icon ?? "folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.gold)
                Text(selectedCategory?.name ?? "Выберите категорию")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(selectedCategory == nil ? Palette.inkTertiary : Palette.ink)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func fieldBlock<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: label)
            content()
                .font(.system(size: 15))
                .foregroundColor(Palette.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )
        }
    }

    private func save() {
        menu.errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= 2 else {
            menu.errorMessage = "Введите название блюда (минимум 2 символа)."
            return
        }
        guard let price = PriceParser.value(from: priceText), price > 0 else {
            menu.errorMessage = "Укажите корректную цену больше нуля."
            return
        }
        guard let categoryId,
              menu.categories.contains(where: { $0.id == categoryId }) else {
            menu.errorMessage = "Выберите категорию для блюда."
            return
        }
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)

        if let item {
            var updated = item
            updated.name = trimmedName
            updated.price = price
            updated.categoryId = categoryId
            updated.details = trimmedDetails
            updated.isAvailable = isAvailable
            menu.updateItem(updated)
        } else {
            _ = menu.addItem(
                name: trimmedName,
                price: price,
                categoryId: categoryId,
                details: trimmedDetails,
                isAvailable: isAvailable
            )
        }

        if menu.errorMessage == nil {
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}
