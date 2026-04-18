import SwiftUI
import UserNotifications

@main
struct LocalFlowApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openSettings) private var openSettings
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(openSettings: { activateAndOpenSettings() })
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isServerRunning ? "waveform.circle.fill" : "waveform.circle")
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }

    private func activateAndOpenSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Notifications] Permission granted")
            } else {
                print("[Notifications] Permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }

        // Watch for window close to hide from dock
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let hasVisibleWindows = NSApp.windows.contains {
                    $0.isVisible && !$0.className.contains("StatusBar")
                }
                if !hasVisibleWindows {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
