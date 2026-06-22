import SwiftUI

@main
struct DuckMapApp: App {
    @StateObject private var db = DuckDBManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(db)
                .frame(minWidth: 1100, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
