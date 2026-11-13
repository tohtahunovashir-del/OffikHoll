import Foundation
import SwiftUI

@main
struct BloknotApp: App {
    init() {
        // Прогреваем базу и демо-меню до первого экрана.
        _ = AppDependencies.shared
    }

    var body: some Scene {
        WindowGroup {
            TablesGridView()
                .preferredColorScheme(nil)
        }
    }
}
