import SwiftUI
import UserNotifications

@main
struct LocalFlowApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("LocalFlow", id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.recorder)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 780, height: 520)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isServerRunning ? "waveform.circle.fill" : "waveform.circle")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Notifications] Permission granted")
            } else {
                print("[Notifications] Permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }

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
