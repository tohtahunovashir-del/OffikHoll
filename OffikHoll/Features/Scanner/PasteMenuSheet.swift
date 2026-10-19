import SwiftUI

struct PasteMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onParse: (String) -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 14) {
                SheetHandle()

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        SectionLabel(text: "Текст меню")
                        Text("Вставить текст")
                            .font(Typeface.display(26, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                    Spacer()
                    CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть") {
                        dismiss()
                    }
                }

                Text("Каждая позиция с новой строки, например:\nБорщ с говядиной .... 420\nЦезарь с курицей 520")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSecondary)
                    .lineSpacing(3)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Вставьте сюда меню…")
                            .font(.system(size: 14))
                            .foregroundColor(Palette.inkTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .foregroundColor(Palette.ink)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color.clear)
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.count >= 5 else { return }
                    onParse(trimmed)
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Text("Разобрать меню")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}
