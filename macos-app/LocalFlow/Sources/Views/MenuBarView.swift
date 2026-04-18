import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isServerRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.isServerRunning ? "Running" : "Stopped")
                    .font(.system(.body, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            menuButton(
                appState.isServerRunning ? "Stop Server" : "Start Server",
                icon: appState.isServerRunning ? "stop.circle" : "play.circle"
            ) {
                if appState.isServerRunning {
                    appState.stopServer()
                } else {
                    appState.startServer()
                }
            }

            menuButton("Settings...", icon: "gear") {
                openSettings()
            }

            Divider()

            menuButton("Quit LocalFlow", icon: "xmark.circle") {
                appState.stopServer()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 180)
        .onAppear {
            if !appState.isServerRunning {
                appState.startServer()
            }
        }
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.system(.caption))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
