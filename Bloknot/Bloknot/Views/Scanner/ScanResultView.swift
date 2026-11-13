import Foundation
import SwiftUI

struct ScanResultView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @ObservedObject var editor: MenuEditorViewModel

    @Environment(\.dismiss) private var dismiss

    init(viewModel: ScannerViewModel, editor: MenuEditorViewModel) {
        self.viewModel = viewModel
        self.editor = editor
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader

            if viewModel.drafts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach($viewModel.drafts) { $draft in
                            ScanDraftRow(
                                draft: $draft,
                                onToggle: { viewModel.toggle(draft) }
                            )
                        }
                    }
                    .padding(.horizontal, Constants.screenPadding)
                    .padding(.vertical, 12)
                }
            }

            footer
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var summaryHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.accentSoft)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Распознано \(Plural.items(viewModel.drafts.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("Проверьте названия и цены перед добавлением")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Constants.screenPadding)
        .padding(.vertical, 10)
        .background(Theme.secondaryBackground)
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Theme.inkTertiary)
            Text("Не удалось распознать блюда.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.ink)
            Text("Попробуйте сфотографировать меню ближе и при хорошем освещении.")
                .font(.system(size: 13))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Сканировать снова") {
                viewModel.reset()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 48)
            .padding(.top, 6)
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Выбрано \(viewModel.includedCount) из \(viewModel.drafts.count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.inkSecondary)

                Spacer(minLength: 0)

                if viewModel.attentionCount > 0 {
                    Text("\(viewModel.attentionCount) требуют внимания")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.yellow)
                }
            }

            Button {
                let inserted = viewModel.importSelected(into: editor)
                if inserted > 0 {
                    dismiss()
                }
            } label: {
                Text("Добавить \(Plural.items(viewModel.includedCount)) в меню")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canImport)
            .opacity(viewModel.canImport ? 1 : 0.5)

            Button("Отменить") {
                dismiss()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Theme.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, Constants.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

// MARK: - Row

private struct ScanDraftRow: View {
    @Binding var draft: ScanDraft
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: draft.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(draft.isIncluded ? Theme.accent : Theme.inkTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Название", text: $draft.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.ink)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        TextField("Цена", text: $draft.priceText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .frame(width: 68)
                        Text("₽")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.inkSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.secondaryBackground)
                    )

                    Text(draft.categoryName)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.inkSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    confidenceDot
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(draft.needsAttention ? Theme.yellowSoft : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(draft.needsAttention ? Theme.yellow.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    private var confidenceDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForConfidence)
                .frame(width: 6, height: 6)
            Text(String(format: "%.2f", draft.confidence))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Theme.inkTertiary)
        }
    }

    private var colorForConfidence: Color {
        if draft.confidence >= 0.75 { return Theme.green }
        if draft.confidence >= 0.55 { return Theme.yellow }
        return Theme.red
    }
}
