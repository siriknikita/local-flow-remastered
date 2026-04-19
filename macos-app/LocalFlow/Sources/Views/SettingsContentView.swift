import SwiftUI

struct SettingsContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var audioDir: String = ""
    @State private var transcriptionDir: String = ""
    @State private var port: String = ""
    @State private var autoTranscribe: Bool = true
    @State private var autoDelete: Bool = false
    @State private var superWhisperPath: String = ""
    @State private var filenamePrefix: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                generalCard
                transcriptionCard
                devicesCard

                Button("Save") { saveConfig() }
                    .buttonStyle(.glassProminent)
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .onAppear { loadConfig() }
    }

    // MARK: - General

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.headline)

            settingsRow("Server Port") {
                TextField("8080", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            settingsRow("Filename Prefix") {
                TextField("localflow", text: $filenamePrefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            settingsRow("Audio Directory") {
                HStack {
                    TextField("Path", text: $audioDir)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseDirectory(binding: $audioDir) }
                }
            }

            settingsRow("Transcription Directory") {
                HStack {
                    TextField("Path", text: $transcriptionDir)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseDirectory(binding: $transcriptionDir) }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Transcription

    private var transcriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription")
                .font(.headline)

            settingsRow("Auto-transcribe on receive") {
                Toggle("", isOn: $autoTranscribe)
                    .labelsHidden()
            }

            settingsRow("Delete audio after transcription") {
                Toggle("", isOn: $autoDelete)
                    .labelsHidden()
            }

            settingsRow("SuperWhisper Recordings") {
                HStack {
                    TextField("Path", text: $superWhisperPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseDirectory(binding: $superWhisperPath) }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Devices

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.headline)

            if appState.pairedDevices.isEmpty {
                Text("No paired devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(appState.pairedDevices) { device in
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(device.deviceName)
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
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .frame(width: 220, alignment: .leading)
            content()
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
        appState.config.audioSaveDirectory = audioDir
        appState.config.transcriptionSaveDirectory = transcriptionDir
        appState.config.serverPort = Int(port) ?? 8080
        appState.config.autoTranscribe = autoTranscribe
        appState.config.autoDeleteAudioAfterTranscription = autoDelete
        appState.config.superWhisperRecordingsPath = superWhisperPath
        appState.config.filenamePrefix = filenamePrefix
        appState.config.save()
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
