import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case pairing = "Pairing"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .pairing: "link"
        case .settings: "gear"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarTab = .home

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedTab)
        } detail: {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .pairing:
                    PairingView()
                case .settings:
                    SettingsContentView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
