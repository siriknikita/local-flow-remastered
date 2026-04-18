import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var audioDir: String = ""
    @State private var transcriptionDir: String = ""
    @State private var port: String = ""
    @State private var autoTranscribe: Bool = true
    @State private var autoDelete: Bool = false
    @State private var superWhisperPath: String = ""
    @State private var filenamePrefix: String = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            transcriptionTab
                .tabItem { Label("Transcription", systemImage: "waveform") }
            devicesTab
                .tabItem { Label("Devices", systemImage: "iphone") }
        }
        .frame(width: 520, height: 480)
        .onAppear { loadConfig() }
    }

    private var generalTab: some View {
        Form {
            Section("Server") {
                TextField("Port", text: $port)
                    .frame(width: 100)
                TextField("Filename Prefix", text: $filenamePrefix)
            }

            Section("Directories") {
                HStack {
                    TextField("Audio Save Directory", text: $audioDir)
                    Button("Browse...") { browseDirectory(binding: $audioDir) }
                }
                HStack {
                    TextField("Transcription Save Directory", text: $transcriptionDir)
                    Button("Browse...") { browseDirectory(binding: $transcriptionDir) }
                }
            }

            Section {
                Button("Save") { saveConfig() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var transcriptionTab: some View {
        Form {
            Section("SuperWhisper") {
                Toggle("Auto-transcribe on receive", isOn: $autoTranscribe)
                Toggle("Delete audio after transcription", isOn: $autoDelete)
                HStack {
                    TextField("SuperWhisper Recordings Path", text: $superWhisperPath)
                    Button("Browse...") { browseDirectory(binding: $superWhisperPath) }
                }
            }

            Section {
                Button("Save") { saveConfig() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var devicesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pending pairing code
            if let pairing = appState.pendingPairing, !pairing.isExpired {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(.orange)
                        Text("\(pairing.deviceName) wants to pair")
                            .font(.body)
                        Spacer()
                    }
                    Text(pairing.code)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .kerning(8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Enter this code on your Android device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )

                Divider()
            }

            // Paired devices
            Text("Paired Devices")
                .font(.headline)

            if appState.pairedDevices.isEmpty {
                Text("No paired devices. Open LocalFlow on your Android device to pair.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(appState.pairedDevices) { device in
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(device.deviceName)
                                    .font(.body)
                                Text("Paired \(device.pairedAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                appState.removePairedDevice(device)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }

            // Recent uploads
            if !appState.recentUploads.isEmpty {
                Divider()
                Text("Recent Uploads")
                    .font(.headline)
                List {
                    ForEach(appState.recentUploads.prefix(10)) { upload in
                        HStack {
                            Image(systemName: statusIcon(upload.transcriptionStatus))
                                .foregroundStyle(statusColor(upload.transcriptionStatus))
                            VStack(alignment: .leading) {
                                Text(upload.filename)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text("\(upload.deviceName) — \(upload.receivedAt.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(upload.transcriptionStatus.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
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

    private func loadConfig() {
        let config = appState.config
        audioDir = config.audioSaveDirectory
        transcriptionDir = config.transcriptionSaveDirectory
        port = String(config.serverPort)
        autoTranscribe = config.autoTranscribe
        autoDelete = config.autoDeleteAudioAfterTranscription
        superWhisperPath = config.superWhisperRecordingsPath
        filenamePrefix = config.filenamePrefix
    }

    private func saveConfig() {
        var config = appState.config
        config.audioSaveDirectory = audioDir
        config.transcriptionSaveDirectory = transcriptionDir
        config.serverPort = Int(port) ?? 8080
        config.autoTranscribe = autoTranscribe
        config.autoDeleteAudioAfterTranscription = autoDelete
        config.superWhisperRecordingsPath = superWhisperPath
        config.filenamePrefix = filenamePrefix
        config.save()
    }

    private func browseDirectory(binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }
}
