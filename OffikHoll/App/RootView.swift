import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var selectedTab: AppTab = .floor

    var body: some View {
        TabView(selection: $selectedTab) {
            FloorView()
                .tabItem {
                    Label("Зал", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.floor)

            ActiveOrdersView()
                .tabItem {
                    Label("Заказы", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.orders)

            MenuView()
                .tabItem {
                    Label("Меню", systemImage: "fork.knife")
                }
                .tag(AppTab.menu)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        .onAppear {
            if let note = environment.storageNote {
                environment.floorStore.errorMessage = note
            }
        }
    }
}
