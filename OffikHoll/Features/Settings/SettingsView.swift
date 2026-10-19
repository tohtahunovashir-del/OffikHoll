import SwiftUI
import UniformTypeIdentifiers

/// Settings tab: identity of the venue/waiter, appearance, haptics,
/// offline backup/restore and app information. Everything is stored in
/// `UserDefaults` except the data itself, which lives in GRDB.
struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var menu: MenuStore
    @EnvironmentObject private var floor: FloorStore

    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("venueName") private var venueName = "OffikHoll"
    @AppStorage("waiterName") private var waiterName = "Официант"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var shareItem: ShareItem?
    @State private var showRestorePicker = false
    @State private var pendingRestoreURL: URL?
    @State private var restoreSummary: RestoreSummary?
    @State private var isWorking = false
    @State private var localError: String?

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let note = environment.storageNote {
                        warningBanner(
                            icon: "externaldrive.badge.exclamationmark",
                            text: note,
                            tint: Palette.gold
                        )
                    }

                    if let restoreSummary {
                        successBanner(summary: restoreSummary)
                    }

                    profileCard
                    appearanceCard
                    serviceCard
                    dataCard
                    statsCard
                    aboutCard
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(
            isPresented: $showRestorePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .confirmationDialog(
            "Восстановить данные из копии?",
            isPresented: Binding(
                get: { pendingRestoreURL != nil },
                set: { if !$0 { pendingRestoreURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Восстановить", role: .destructive) {
                if let url = pendingRestoreURL {
                    restore(from: url)
                }
                pendingRestoreURL = nil
            }
            Button("Отмена", role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text("Текущее меню, столы и заказы будут заменены содержимым файла. Действие нельзя отменить.")
        }
        .errorAlert($localError)
        .onDisappear(perform: normalizeNames)
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            eyebrow: "OffikHoll · офлайн",
            title: "Настройки",
            subtitle: "Версия \(AppFormat.versionString())"
        ) {
            ZStack {
                Circle()
                    .fill(Palette.goldSoft)
                    .frame(width: 44, height: 44)
                Text("O")
                    .font(Typeface.display(20, weight: .semibold))
                    .foregroundColor(Palette.gold)
            }
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Заведение и смена")

            settingsField(
                icon: "building.2",
                title: "Название заведения",
                placeholder: "OffikHoll",
                text: $venueName
            )

            DividerLine()

            settingsField(
                icon: "person.crop.circle",
                title: "Имя официанта",
                placeholder: "Официант",
                text: $waiterName
            )

            Text("Имя видно на главном экране и в шапке зала. Изменения сохраняются автоматически.")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .premiumCard()
    }

    private func settingsField(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 11) {
            IconBadge(icon: icon, tint: Palette.inkSecondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(0.9)
                    .foregroundColor(Palette.inkTertiary)
                TextField(placeholder, text: text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Оформление")

            HStack(spacing: 9) {
                ForEach(AppearanceMode.allCases) { mode in
                    appearanceTile(mode)
                }
            }

            Text("Системная тема следует настройкам iPhone и переключается автоматически.")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .premiumCard()
    }

    private func appearanceTile(_ mode: AppearanceMode) -> some View {
        let selected = appearance == mode
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                appearanceRaw = mode.rawValue
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(previewBackground(for: mode))

                    VStack(alignment: .leading, spacing: 4) {
                        Capsule()
                            .fill(previewInk(for: mode).opacity(0.85))
                            .frame(width: 22, height: 3.5)
                        Capsule()
                            .fill(previewInk(for: mode).opacity(0.35))
                            .frame(width: 34, height: 3)
                        Capsule()
                            .fill(previewInk(for: mode).opacity(0.2))
                            .frame(width: 28, height: 3)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(6)
                    }
                }
                .frame(height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            selected ? Palette.accent : Palette.stroke,
                            lineWidth: selected ? 1.6 : 1
                        )
                )

                Text(mode.title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundColor(selected ? Palette.ink : Palette.inkSecondary)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Palette.accentSoft.opacity(0.55) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Тема: \(mode.title)")
    }

    private func previewBackground(for mode: AppearanceMode) -> LinearGradient {
        switch mode {
        case .light:
            return LinearGradient(
                colors: [Color(hex: 0xFBF8F1), Color(hex: 0xF0EBE0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(hex: 0x141B18), Color(hex: 0x090D0B)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .system:
            return LinearGradient(
                colors: [Color(hex: 0xFBF8F1), Color(hex: 0xF0EBE0), Color(hex: 0x141B18), Color(hex: 0x090D0B)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func previewInk(for mode: AppearanceMode) -> Color {
        switch mode {
        case .light:
            return Color(hex: 0x14181A)
        case .dark:
            return Color(hex: 0xF4F2EC)
        case .system:
            return Color(hex: 0x8B938E)
        }
    }

    // MARK: - Service

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Сервис")

            Toggle(isOn: $hapticsEnabled) {
                HStack(spacing: 11) {
                    IconBadge(icon: "iphone.radiowaves.left.and.right", tint: Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Тактильный отклик")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Palette.ink)
                        Text("Вибрация при действиях и ошибках")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.inkTertiary)
                    }
                }
            }
            .tint(Palette.accent)
            .onChange(of: hapticsEnabled) { enabled in
                if enabled { Haptics.selection() }
            }

            DividerLine()
                .opacity(0.7)

            HStack(spacing: 11) {
                IconBadge(icon: "wifi.slash", tint: Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Полностью офлайн")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.ink)
                    Text("Меню, заказы и сканер не требуют сети")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkTertiary)
                }
                Spacer(minLength: 4)
                StatusPill(text: "ВКЛ", color: Palette.accent)
            }
        }
        .padding(16)
        .premiumCard()
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Данные")

            actionRow(
                icon: "externaldrive.badge.timemachine",
                title: "Резервная копия",
                subtitle: "Меню, столы и заказы в одном JSON",
                tint: Palette.accent
            ) {
                exportBackup()
            }

            DividerLine().opacity(0.7)

            actionRow(
                icon: "arrow.down.doc",
                title: "Восстановить из копии",
                subtitle: "Заменит текущие данные",
                tint: Palette.gold
            ) {
                showRestorePicker = true
            }

            DividerLine().opacity(0.7)

            actionRow(
                icon: "tablecells",
                title: "Меню в CSV",
                subtitle: "Для Excel и Google Таблиц",
                tint: Palette.inkSecondary
            ) {
                exportMenu(asJSON: false)
            }

            DividerLine().opacity(0.7)

            actionRow(
                icon: "curlybraces",
                title: "Меню в JSON",
                subtitle: "Для интеграций и бэкапа",
                tint: Palette.inkSecondary
            ) {
                exportMenu(asJSON: true)
            }

            if isWorking {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text("Готовим файл…")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .premiumCard()
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isWorking else { return }
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 11) {
                IconBadge(icon: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Palette.ink)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkTertiary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
            }
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    // MARK: - Stats

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "В базе")

            HStack(alignment: .center, spacing: 0) {
                StatBlock(title: "Блюд", value: "\(menu.items.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)

                divider

                StatBlock(title: "Категорий", value: "\(menu.categories.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                divider

                StatBlock(title: "Столов", value: "\(floor.cards.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                divider

                StatBlock(
                    title: "Открыто",
                    value: "\(floor.stats.openOrders)",
                    tint: Palette.gold,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 16)
            }

            Text("Выручка сегодня: \(Price.string(floor.stats.revenueToday)). Данные хранятся в SQLite на этом устройстве.")
                .font(.system(size: 10.5))
                .foregroundColor(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .premiumCard()
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1, height: 30)
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Palette.ink, Palette.ink.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Text("OH")
                        .font(Typeface.display(19, weight: .semibold))
                        .foregroundColor(Palette.gold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("OffikHoll")
                        .font(Typeface.display(20, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("Официант · премиум")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Palette.inkSecondary)
                }

                Spacer(minLength: 4)

                Text("v\(AppFormat.versionString())")
                    .font(Typeface.number(11, weight: .semibold))
                    .foregroundColor(Palette.inkTertiary)
            }

            DividerLine()

            VStack(alignment: .leading, spacing: 7) {
                aboutLine(icon: "bolt.horizontal.circle", text: "Мгновенные заказы без модальных окон")
                aboutLine(icon: "doc.viewfinder", text: "Сканер меню на Vision: 8 языков")
                aboutLine(icon: "lock.doc", text: "GRDB/SQLite, без облака и сети")
                aboutLine(icon: "paintbrush", text: "Светлая и тёмная темы, крупные кнопки")
            }

            Text("© 2026 OffikHoll. Сделано для официантов, которые ценят скорость.")
                .font(.system(size: 10))
                .foregroundColor(Palette.inkTertiary)
                .padding(.top, 2)
        }
        .padding(16)
        .premiumCard()
    }

    private func aboutLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Palette.gold)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(Palette.inkSecondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("OFFIKHOLL · ОФИЦИАНТ")
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(Palette.inkTertiary)
            Text("Работает без интернета")
                .font(.system(size: 10))
                .foregroundColor(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Banners

    private func warningBanner(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.goldSoft)
        )
    }

    private func successBanner(summary: RestoreSummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Palette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Копия восстановлена")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text(summary.text)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    restoreSummary = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.inkTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.accentSoft)
        )
    }

    // MARK: - Actions

    private func normalizeNames() {
        let venue = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        venueName = venue.isEmpty ? "OffikHoll" : venue
        let waiter = waiterName.trimmingCharacters(in: .whitespacesAndNewlines)
        waiterName = waiter.isEmpty ? "Официант" : waiter
    }

    private func exportBackup() {
        isWorking = true
        defer { isWorking = false }
        do {
            let url = try BackupService.writeFullBackup(database: environment.database)
            shareItem = ShareItem(url: url)
            Haptics.success()
        } catch {
            localError = "Не удалось создать резервную копию: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func exportMenu(asJSON: Bool) {
        isWorking = true
        defer { isWorking = false }
        do {
            let url = try asJSON
                ? BackupService.writeMenuJSON(categories: menu.categories, items: menu.items)
                : BackupService.writeMenuCSV(categories: menu.categories, items: menu.items)
            shareItem = ShareItem(url: url)
            Haptics.success()
        } catch {
            localError = "Не удалось экспортировать меню: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            pendingRestoreURL = url
        case let .failure(error):
            localError = "Не удалось открыть файл: \(error.localizedDescription)"
        }
    }

    private func restore(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let summary = try BackupService.restore(database: environment.database, from: url)
            withAnimation(.easeOut(duration: 0.2)) {
                restoreSummary = summary
            }
            Haptics.success()
        } catch {
            localError = "Не удалось восстановить копию: \(error.localizedDescription)"
            Haptics.error()
        }
    }
}
