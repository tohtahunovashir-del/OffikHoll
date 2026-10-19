import SwiftUI

struct CategoryEditorView: View {
    @EnvironmentObject private var menu: MenuStore
    @Environment(\.dismiss) private var dismiss

    private let category: Category?

    @State private var name: String
    @State private var icon: String
    @State private var showDeleteConfirm = false
    @FocusState private var nameFocused: Bool

    init(category: Category?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? CategoryIcons.defaultIcon)
    }

    private var isEditing: Bool { category != nil }

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "Название категории")
                        TextField("Например: Салаты", text: $name)
                            .font(.system(size: 15))
                            .foregroundColor(Palette.ink)
                            .focused($nameFocused)
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

                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(text: "Иконка")
                        LazyVGrid(columns: iconColumns, spacing: 9) {
                            ForEach(CategoryIcons.all, id: \.self) { symbol in
                                Button {
                                    Haptics.selection()
                                    icon = symbol
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(icon == symbol ? Palette.accentFill : Palette.surface)
                                        Image(systemName: symbol)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(icon == symbol ? .white : Palette.inkSecondary)
                                    }
                                    .frame(height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .strokeBorder(
                                                icon == symbol ? Color.clear : Palette.stroke,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(symbol)
                            }
                        }
                    }

                    if let category {
                        HStack(spacing: 12) {
                            IconBadge(icon: "fork.knife", tint: Palette.gold, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("В категории")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Palette.inkSecondary)
                                Text("\(menu.itemCount(in: category.id)) \(AppFormat.plural(menu.itemCount(in: category.id), "блюдо", "блюда", "блюд"))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Palette.ink)
                            }
                            Spacer()
                        }
                        .premiumCard(padding: 12, cornerRadius: 16)
                    }

                    Button {
                        save()
                    } label: {
                        Text(isEditing ? "Сохранить категорию" : "Создать категорию")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 2)

                    if isEditing {
                        Button("Удалить категорию") {
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
            if !isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    nameFocused = true
                }
            }
        }
        .confirmationDialog(
            "Удалить категорию?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let category {
                    menu.deleteCategory(category)
                    Haptics.warning()
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            if let category {
                let count = menu.itemCount(in: category.id)
                Text(count > 0
                     ? "Вместе с «\(category.name)» будут удалены \(count) \(AppFormat.plural(count, "блюдо", "блюда", "блюд"))."
                     : "Категория «\(category.name)» будет удалена.")
            } else {
                Text("Категория будет удалена.")
            }
        }
        .errorAlert($menu.errorMessage)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isEditing ? "РЕДАКТИРОВАНИЕ" : "НОВАЯ КАТЕГОРИЯ")
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(1.4)
                    .foregroundColor(Palette.gold)
                Text(isEditing ? "Категория" : "Добавить категорию")
                    .font(Typeface.display(26, weight: .semibold))
                    .foregroundColor(Palette.ink)
            }
            Spacer(minLength: 4)
            CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть") {
                dismiss()
            }
        }
    }

    private func save() {
        menu.errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            menu.errorMessage = "Введите название категории."
            return
        }
        if let category {
            menu.updateCategory(category, name: trimmed, icon: icon)
        } else {
            _ = menu.addCategory(name: trimmed, icon: icon)
        }
        if menu.errorMessage == nil {
            Haptics.success()
            dismiss()
        } else {
            Haptics.error()
        }
    }
}
