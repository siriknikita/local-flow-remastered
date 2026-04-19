import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: SidebarTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Branding
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("LocalFlow")
                    .font(.title3.bold())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)

            // Navigation items
            ForEach(SidebarTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SidebarButtonStyle(isSelected: selection == tab))
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
            }

            Spacer(minLength: 0)

            // Server status with menu
            ServerStatusButton(isRunning: appState.isServerRunning) {
                if appState.isServerRunning {
                    appState.stopServer()
                } else {
                    appState.startServer()
                }
            } onQuit: {
                appState.stopServer()
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 180, maxHeight: .infinity)
    }
}

private struct ServerStatusButton: View {
    let isRunning: Bool
    let onToggle: () -> Void
    let onQuit: () -> Void

    @State private var showingMenu = false

    var body: some View {
        Button {
            showingMenu = true
        } label: {
            HStack(spacing: 6) {
                Canvas { context, size in
                    let rect = CGRect(x: 0, y: (size.height - 8) / 2, width: 8, height: 8)
                    context.fill(Circle().path(in: rect), with: .color(isRunning ? .green : .red))
                }
                .frame(width: 8, height: 8)

                Text(isRunning ? "Server Running" : "Server Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingMenu, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showingMenu = false
                    onToggle()
                } label: {
                    Label(
                        isRunning ? "Stop Server" : "Start Server",
                        systemImage: isRunning ? "stop.circle" : "play.circle"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    showingMenu = false
                    onQuit()
                } label: {
                    Label("Quit LocalFlow", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .frame(width: 180)
        }
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.selection)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
