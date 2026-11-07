import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.scenePhase) private var scenePhase

    private var palette: MochyPalette {
        MochyTheme.palette(settings: store.settings, artworkColor: player.artworkColor)
    }

    var body: some View {
        Group {
            if store.settings.onboardingCompleted {
                mainContent
            } else {
                OnboardingView()
            }
        }
        .environment(\.mochyPalette, palette)
        .preferredColorScheme(.dark)
        .tint(palette.accent)
    }

    private var mainContent: some View {
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()

            Group {
                switch store.selectedTab {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .library:
                    LibraryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let toast = store.toast {
                ToastView(message: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                MiniPlayerBar()
                MainTabBar()
            }
        }
        .fullScreenCover(isPresented: $store.playerPresented) {
            NavigationStack {
                PlayerScreen()
            }
            .environment(\.openRouteAction, { (route: AppRoute) in
                store.playerRoute = route
            })
            .statusBar(hidden: store.settings.hideStatusBarInPlayer)
            .onDisappear {
                store.playerRoute = nil
            }
            .environmentObject(store)
            .environmentObject(store.player)
            .environment(\.mochyPalette, palette)
        }
        .task {
            await store.loadHome()
        }
        .onChange(of: scenePhase) { _, phase in
            store.handleScenePhase(phase)
        }
        .onChange(of: store.selectedTab) { _, _ in
            store.navigationRequest = nil
        }
    }
}
