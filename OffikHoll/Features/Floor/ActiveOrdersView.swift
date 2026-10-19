import SwiftUI

struct ActiveOrdersView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var floor: FloorStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        statsCard
                        ordersList
                        paidCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: OrderRoute.self) { route in
                OrderScreen(orderId: route.orderId, database: environment.database)
            }
            .errorAlert($floor.errorMessage)
        }
    }

    private var header: some View {
        ScreenHeader(
            eyebrow: "Сервис · онлайн-зал",
            title: "Заказы",
            subtitle: "Открытые счета и выручка сегодня"
        ) {
            ZStack {
                Circle()
                    .fill(Palette.goldSoft)
                    .frame(width: 46, height: 46)
                Text("\(floor.openCards.count)")
                    .font(Typeface.number(18, weight: .semibold))
                    .foregroundColor(Palette.gold)
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBlock(
                title: "Счетов",
                value: "\(floor.stats.openOrders)",
                tint: Palette.ink
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            divider

            StatBlock(
                title: "Сумма",
                value: Price.compact(floor.stats.openTotal),
                tint: Palette.accent
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            divider

            StatBlock(
                title: "Выручка",
                value: Price.compact(floor.stats.revenueToday),
                tint: Palette.gold,
                alignment: .trailing
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 16)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .premiumCard(padding: 0, cornerRadius: 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var ordersList: some View {
        if floor.openCards.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "Открытых заказов нет",
                message: "Выберите стол в зале — заказ откроется в одно касание."
            )
            .premiumCard(padding: 6, cornerRadius: 24)
        } else {
            if !floor.newOrderCards.isEmpty {
                orderSection(title: "Новые", cards: floor.newOrderCards)
            }
            if !floor.sentOrderCards.isEmpty {
                orderSection(title: "На кухне", cards: floor.sentOrderCards)
            }
        }
    }

    private func orderSection(title: String, cards: [FloorCard]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            ForEach(cards) { card in
                Button {
                    guard let orderId = card.order?.id else { return }
                    Haptics.impact(.light)
                    path.append(OrderRoute(orderId: orderId))
                } label: {
                    OrderRowCard(card: card)
                }
                .buttonStyle(TableCardButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var paidCard: some View {
        if floor.stats.paidOrdersToday > 0 {
            HStack(spacing: 14) {
                IconBadge(icon: "checkmark.seal.fill", tint: Palette.accent, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Оплачено сегодня")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("\(floor.stats.paidOrdersToday) \(AppFormat.plural(floor.stats.paidOrdersToday, "заказ", "заказа", "заказов")) · \(Price.string(floor.stats.revenueToday))")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.inkSecondary)
                }
                Spacer()
            }
            .premiumCard(padding: 14, cornerRadius: 18)
        }
    }
}

struct OrderRowCard: View {
    let card: FloorCard

    private var status: OrderStatus { card.status ?? .active }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(status.color.opacity(0.12))
                VStack(spacing: 0) {
                    Text("№")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(status.color.opacity(0.7))
                    Text("\(card.table.number)")
                        .font(Typeface.display(23, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
            }
            .frame(width: 56, height: 60)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    StatusPill(text: status.title, color: status.color)
                    Spacer(minLength: 0)
                    Text(AppFormat.time(card.openedAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.inkTertiary)
                }
                Text(card.previewLines.first ?? "Заказ открыт")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    MetaLabel(icon: "person.2.fill", text: "\(card.guests)")
                    MetaLabel(icon: "clock", text: AppFormat.elapsed(since: card.openedAt))
                    Spacer(minLength: 0)
                    Text(Price.string(card.total))
                        .font(Typeface.number(15, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Palette.inkTertiary)
        }
        .premiumCard(padding: 14, cornerRadius: 20)
        .contentShape(Rectangle())
    }
}
