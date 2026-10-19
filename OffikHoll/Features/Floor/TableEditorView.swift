import SwiftUI

/// Create or edit a table. Number uniqueness, seat bounds and the
/// "occupied tables cannot be deleted" rule live in `FloorStore`; this view
/// only collects input and surfaces the Russian error it returns.
struct TableEditorView: View {
    @EnvironmentObject private var floor: FloorStore
    @Environment(\.dismiss) private var dismiss

    private let existingTable: RestaurantTable?

    @State private var numberText: String
    @State private var seats: Int
    @State private var zone: String
    @State private var showDeleteConfirm = false
    @State private var localError: String?
    @FocusState private var numberFocused: Bool

    private let defaultZones = ["Основной зал", "Терраса", "Бар", "Летняя веранда"]

    init(existingTable: RestaurantTable?) {
        self.existingTable = existingTable
        _numberText = State(initialValue: existingTable.map { "\($0.number)" } ?? "")
        _seats = State(initialValue: existingTable?.seats ?? 2)
        _zone = State(initialValue: existingTable?.zone ?? "Основной зал")
    }

    private var isEditing: Bool { existingTable != nil }

    private var isOccupied: Bool {
        guard let existingTable else { return false }
        return floor.card(for: existingTable.id)?.isOccupied == true
    }

    private var suggestedZones: [String] {
        var result = defaultZones
        for name in floor.zones where !result.contains(name) {
            result.append(name)
        }
        return result
    }

    private var parsedNumber: Int? {
        Int(numberText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        guard let parsedNumber, parsedNumber > 0 else { return false }
        return seats >= 1 && seats <= 30
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SheetHandle()

                    header

                    basicsCard
                    seatsCard
                    zoneCard

                    if isEditing {
                        deleteSection
                    }

                    Button {
                        save()
                    } label: {
                        Text(isEditing ? "Сохранить изменения" : "Добавить стол")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .confirmationDialog(
            "Удалить стол № \(existingTable?.number ?? 0)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить стол", role: .destructive) {
                deleteTable()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Стол исчезнет с карты зала. Отменить это действие нельзя.")
        }
        .errorAlert(
            Binding<String?>(
                get: { localError ?? floor.errorMessage },
                set: { value in
                    if value == nil {
                        localError = nil
                        floor.errorMessage = nil
                    }
                }
            )
        )
        .onAppear {
            if !isEditing {
                numberFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: isEditing ? "Стол № \(existingTable?.number ?? 0)" : "Новый стол")
                Text(isEditing ? "Изменить стол" : "Добавить стол")
                    .font(Typeface.display(27, weight: .semibold))
                    .foregroundColor(Palette.ink)
            }
            Spacer(minLength: 8)
            CircleIconButton(icon: "xmark", accessibilityTitle: "Закрыть") {
                dismiss()
            }
        }
    }

    // MARK: - Number

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: "Номер стола")

            HStack(spacing: 12) {
                TextField("Например: 12", text: $numberText)
                    .font(Typeface.display(30, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .keyboardType(.numberPad)
                    .focused($numberFocused)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let parsedNumber, parsedNumber > 0 {
                    Text("#\(parsedNumber)")
                        .font(Typeface.number(12, weight: .semibold))
                        .foregroundColor(Palette.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Palette.accentSoft))
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        parsedNumber == nil && !numberText.isEmpty
                            ? Palette.danger.opacity(0.5)
                            : Palette.stroke,
                        lineWidth: 1
                    )
            )

            Text("Номер должен быть уникальным — два стола с одним номером создать нельзя.")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .premiumCard()
    }

    // MARK: - Seats

    private var seatsCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "Мест за столом")
                Text("\(seats) \(AppFormat.plural(seats, "место", "места", "мест"))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.inkSecondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                seatButton(icon: "minus", enabled: seats > 1) {
                    seats = max(1, seats - 1)
                }

                Text("\(seats)")
                    .font(Typeface.number(22, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44)

                seatButton(icon: "plus", enabled: seats < 30) {
                    seats = min(30, seats + 1)
                }
            }
            .padding(4)
            .background(Capsule().fill(Palette.surfaceMuted))
            .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        }
        .padding(16)
        .premiumCard()
    }

    private func seatButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptics.selection()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? Palette.ink : Palette.inkTertiary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Zone

    private var zoneCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(text: "Зона зала")

            TextField("Например: Основной зал", text: $zone)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Palette.ink)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 15)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedZones, id: \.self) { name in
                        FilterChip(
                            title: name,
                            isSelected: zone.trimmingCharacters(in: .whitespacesAndNewlines) == name
                        ) {
                            zone = name
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16)
        .premiumCard()
    }

    // MARK: - Delete

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if isOccupied {
                    localError = "Сначала закройте заказ на этом столе, затем удалите его."
                    Haptics.error()
                } else {
                    showDeleteConfirm = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Удалить стол")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .opacity(isOccupied ? 0.5 : 1)

            if isOccupied {
                Text("Стол занят: действующий заказ нужно закрыть или отменить.")
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.inkTertiary)
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard let number = parsedNumber, number > 0 else {
            localError = "Введите номер стола больше нуля."
            Haptics.error()
            return
        }

        let error: String?
        if let existingTable {
            error = floor.updateTable(existingTable, number: number, seats: seats, zone: zone)
        } else {
            error = floor.addTable(number: number, seats: seats, zone: zone)
        }

        if let error {
            localError = error
            Haptics.error()
        } else {
            Haptics.success()
            dismiss()
        }
    }

    private func deleteTable() {
        guard let existingTable else { return }
        if let error = floor.deleteTable(existingTable) {
            localError = error
            Haptics.error()
        } else {
            Haptics.success()
            dismiss()
        }
    }
}
