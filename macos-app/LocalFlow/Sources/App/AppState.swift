import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isServerRunning = false
    @Published var serverPort: Int = 8080
    @Published var lastEvent: String = ""
    @Published var recentUploads: [UploadRecord] = []
    @Published var pairedDevices: [PairedDevice] = []
    @Published var pendingPairing: PairingRequest?
    @Published var activePhoneUpload: PhoneUploadState?
    @Published var phoneRecording: PhoneRecordingState?
    @Published var stopPhoneRequested = false

    struct PhoneUploadState {
        let deviceName: String
        let startedAt: Date
    }

    struct PhoneRecordingState {
        let deviceName: String
        let startedAt: Date
    }

    func setPhoneRecording(deviceName: String, isRecording: Bool) {
        if isRecording {
            phoneRecording = PhoneRecordingState(deviceName: deviceName, startedAt: Date())
            stopPhoneRequested = false
        } else {
            phoneRecording = nil
        }
    }

    func requestPhoneStop() {
        stopPhoneRequested = true
    }

    func clearPhoneStop() {
        stopPhoneRequested = false
    }

    let recorder = MacAudioRecorder()
    var config: AppConfiguration
    let deviceStore: DeviceStore
    private var server: LocalFlowServer?
    private var bonjourAdvertiser: BonjourAdvertiser?

    init() {
        self.config = AppConfiguration.load()
        self.deviceStore = DeviceStore.load()
        self.pairedDevices = deviceStore.devices
    }

    // MARK: - Recording

    func startRecording() {
        _ = recorder.startRecording(
            saveDirectory: config.audioSaveDirectory,
            filenamePrefix: config.filenamePrefix
        )
    }

    func stopRecording() {
        guard let fileURL = recorder.stopRecording() else { return }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let uploadId = UUID().uuidString

        let record = UploadRecord(
            id: uploadId,
            filename: fileURL.lastPathComponent,
            deviceName: "Local Recording",
            receivedAt: Date(),
            fileSize: fileSize,
            transcriptionStatus: config.autoTranscribe ? .queued : .skipped
        )
        addUpload(record)

        if config.autoTranscribe {
            Task {
                await transcribeLocalRecording(audioFileURL: fileURL, uploadId: uploadId)
            }
        }
    }

    private func transcribeLocalRecording(audioFileURL: URL, uploadId: String) async {
        let superWhisperPath = URL(fileURLWithPath: config.superWhisperRecordingsPath)
        let swBackend = SuperWhisperBackend(recordingsDirectory: superWhisperPath)

        let backend: TranscriptionBackend = swBackend.isAvailable ? swBackend : StubBackend()

        do {
            let result = try await backend.transcribe(audioFilePath: audioFileURL)

            let timestamp = audioFileURL.deletingPathExtension().lastPathComponent
            let textFilename = "\(timestamp).txt"
            let textDir = URL(fileURLWithPath: config.transcriptionSaveDirectory)
            let textFileURL = textDir.appendingPathComponent(textFilename)

            try FileManager.default.createDirectory(at: textDir, withIntermediateDirectories: true)
            try result.text.write(to: textFileURL, atomically: true, encoding: .utf8)

            updateUploadStatus(uploadId: uploadId, status: .completed)

            if config.autoDeleteAudioAfterTranscription {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
        } catch {
            print("[Transcription] Local recording failed: \(error)")
            updateUploadStatus(uploadId: uploadId, status: .failed)
        }
    }

    private func updateUploadStatus(uploadId: String, status: UploadRecord.TranscriptionStatus) {
        if let idx = recentUploads.firstIndex(where: { $0.id == uploadId }) {
            recentUploads[idx].transcriptionStatus = status
        }
    }

    func startServer() {
        guard !isServerRunning else { return }

        let server = LocalFlowServer(appState: self)
        self.server = server

        Task {
            do {
                try await server.start(port: serverPort)
                isServerRunning = true
                lastEvent = "Server started on port \(serverPort)"

                let advertiser = BonjourAdvertiser(port: serverPort)
                advertiser.startAdvertising()
                self.bonjourAdvertiser = advertiser
            } catch {
                lastEvent = "Failed to start server: \(error.localizedDescription)"
            }
        }
    }

    func stopServer() {
        server?.stop()
        server = nil
        bonjourAdvertiser?.stopAdvertising()
        bonjourAdvertiser = nil
        isServerRunning = false
        lastEvent = "Server stopped"
    }

    func addUpload(_ record: UploadRecord) {
        recentUploads.insert(record, at: 0)
        if recentUploads.count > 50 {
            recentUploads = Array(recentUploads.prefix(50))
        }
    }

    func addPairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.deviceId == device.deviceId }
        pairedDevices.append(device)
        deviceStore.devices = pairedDevices
        deviceStore.save()
    }

    func removePairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.deviceId == device.deviceId }
        deviceStore.devices = pairedDevices
        deviceStore.save()
    }

    func isTokenValid(_ token: String) -> Bool {
        pairedDevices.contains { $0.token == token }
    }

    func deviceName(forToken token: String) -> String? {
        pairedDevices.first { $0.token == token }?.deviceName
    }
}
