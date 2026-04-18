import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isServerRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(appState.isServerRunning ? "Running" : "Stopped")
                    .font(.system(.body, weight: .medium))
                Spacer()
                if appState.isServerRunning {
                    Text("port \(appState.serverPort)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Pending pairing — prominent
            if let pairing = appState.pendingPairing, !pairing.isExpired {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(.orange)
                        Text(pairing.deviceName)
                            .font(.system(.caption, weight: .medium))
                        Spacer()
                    }
                    Text(pairing.code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .kerning(6)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .background(.orange.opacity(0.08))

                Divider()
            }

            // Paired devices
            if !appState.pairedDevices.isEmpty {
                sectionHeader("Paired")
                ForEach(appState.pairedDevices) { device in
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(device.deviceName)
                            .font(.system(.caption))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
                .padding(.bottom, 4)

                Divider()
            }

            // Recent uploads
            if !appState.recentUploads.isEmpty {
                sectionHeader("Recent")
                ForEach(appState.recentUploads.prefix(3)) { upload in
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(upload.transcriptionStatus))
                            .font(.caption)
                            .foregroundStyle(statusColor(upload.transcriptionStatus))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(formatUploadTime(upload.receivedAt))
                                .font(.system(.caption))
                            Text(upload.deviceName)
                                .font(.system(.caption2))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(formatFileSize(upload.fileSize))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
                .padding(.bottom, 4)

                Divider()
            }

            // Controls
            VStack(spacing: 2) {
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
                    .padding(.vertical, 2)

                menuButton("Quit LocalFlow", icon: "xmark.circle") {
                    appState.stopServer()
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 240)
        .onAppear {
            if !appState.isServerRunning {
                appState.startServer()
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
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

    private func formatUploadTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
