import SwiftUI

@main
@MainActor
struct MochyApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.player)
                .preferredColorScheme(.dark)
                .tint(MochyTheme.palette(settings: store.settings, artworkColor: store.player.artworkColor).accent)
        }
    }
}
