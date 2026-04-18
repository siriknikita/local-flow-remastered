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
        .frame(width: 500, height: 400)
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
        VStack(alignment: .leading) {
            Text("Paired Devices")
                .font(.headline)

            if appState.pairedDevices.isEmpty {
                Text("No paired devices")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(appState.pairedDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.deviceName)
                                    .font(.body)
                                Text("Paired: \(device.pairedAt.formatted())")
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
        }
        .padding()
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
