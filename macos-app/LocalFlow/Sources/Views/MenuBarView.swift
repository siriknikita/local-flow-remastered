import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status
            HStack {
                Circle()
                    .fill(appState.isServerRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.isServerRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)
                Spacer()
                Text(":\(appState.serverPort)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.lastEvent.isEmpty {
                Text(appState.lastEvent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            // Paired devices
            if !appState.pairedDevices.isEmpty {
                Text("Paired Devices")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(appState.pairedDevices) { device in
                    HStack {
                        Image(systemName: "iphone")
                        Text(device.deviceName)
                            .font(.caption)
                    }
                }
                Divider()
            }

            // Pending pairing
            if let pairing = appState.pendingPairing, !pairing.isExpired {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pairing Request")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text(pairing.deviceName)
                        .font(.caption)
                    HStack {
                        Text("Code:")
                            .font(.caption)
                        Text(pairing.code)
                            .font(.system(.title2, design: .monospaced).bold())
                    }
                }
                Divider()
            }

            // Recent uploads
            if !appState.recentUploads.isEmpty {
                Text("Recent Uploads")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(appState.recentUploads.prefix(5)) { upload in
                    HStack {
                        Image(systemName: statusIcon(upload.transcriptionStatus))
                            .foregroundStyle(statusColor(upload.transcriptionStatus))
                        VStack(alignment: .leading) {
                            Text(upload.filename)
                                .font(.caption)
                                .lineLimit(1)
                            Text(upload.deviceName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
            }

            // Controls
            Button(appState.isServerRunning ? "Stop Server" : "Start Server") {
                if appState.isServerRunning {
                    appState.stopServer()
                } else {
                    appState.startServer()
                }
            }

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit LocalFlow") {
                appState.stopServer()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            if !appState.isServerRunning {
                appState.startServer()
            }
        }
    }

    private func statusIcon(_ status: UploadRecord.TranscriptionStatus) -> String {
        switch status {
        case .received, .queued: return "clock"
        case .transcribing: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private func statusColor(_ status: UploadRecord.TranscriptionStatus) -> Color {
        switch status {
        case .received, .queued: return .orange
        case .transcribing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}
