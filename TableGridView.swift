import SwiftUI

struct TableGridView: View {
    @EnvironmentObject private var store: RestaurantStore
    private let columns = [GridItem(.adaptive(minimum: 148), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Добрый день")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            Text("Зал")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Label("Офлайн", systemImage: "wifi.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    HStack(spacing: 10) {
                        StatusLegend(color: .green, title: "Свободен")
                        StatusLegend(color: .orange, title: "Занят")
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.tables) { table in
                            NavigationLink {
                                OrderView(table: table)
                            } label: {
                                TableCard(table: table, total: store.tableTotals[table.id] ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        Image(systemName: "fork.knife.circle.fill").foregroundStyle(Color.accentColor)
                        Text("OffikHoll").font(.headline.weight(.bold))
                    }
                }
            }
        }
    }
}

private struct StatusLegend: View {
    let color: Color
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
    }
}

private struct TableCard: View {
    let table: DiningTable
    let total: Double
    private var occupied: Bool { table.status == .occupied }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("\(table.number)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Circle().fill(occupied ? Color.orange : Color.green).frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(occupied ? "Занят" : "Свободен")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(occupied ? Color.orange : Color.green)
                Text(occupied ? total.formatted(.number.precision(.fractionLength(0))) + " ₽" : "Нажмите, чтобы открыть")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(occupied ? Color.orange.opacity(0.28) : Color.clear, lineWidth: 1))
        .shadow(color: .black.opacity(0.045), radius: 9, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
