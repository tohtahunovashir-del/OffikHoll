import SwiftUI

@main
struct OffikHollApp: App {
    @StateObject private var store = RestaurantStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .preferredColorScheme(nil)
                .tint(Color.accentColor)
                .alert("Внимание", isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )) {
                    Button("Понятно", role: .cancel) { store.errorMessage = nil }
                } message: {
                    Text(store.errorMessage ?? "")
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TableGridView()
                .tabItem { Label("Столы", systemImage: "square.grid.2x2.fill") }
            MenuEditorView()
                .tabItem { Label("Меню", systemImage: "menucard.fill") }
        }
    }
}
