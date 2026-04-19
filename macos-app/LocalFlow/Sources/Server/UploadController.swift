import Vapor
import Foundation
import UserNotifications

struct UploadController: Sendable {
    let appState: AppState

    struct UploadResponse: Content {
        let id: String
        let status: String
        let filename: String
    }

    func handleUpload(req: Request) async throws -> UploadResponse {
        // Validate auth token
        guard let authHeader = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization token")
        }

        let token = authHeader.token
        guard await appState.isTokenValid(token) else {
            throw Abort(.unauthorized, reason: "Invalid authorization token")
        }

        let deviceName = await appState.deviceName(forToken: token) ?? "Unknown"

        // Signal that phone is uploading
        await MainActor.run {
            appState.activePhoneUpload = AppState.PhoneUploadState(
                deviceName: deviceName,
                startedAt: Date()
            )
        }

        // Extract audio from multipart form data
        let bytes: Data
        if let file = try? req.content.get(File.self, at: "audio") {
            bytes = Data(buffer: file.data)
        } else if let bodyData = req.body.data {
            // Fallback: treat entire body as audio (for non-multipart clients like curl)
            bytes = Data(buffer: bodyData)
        } else {
            throw Abort(.badRequest, reason: "No audio data in request body")
        }

        // Get filename from query or generate one
        let timestamp = Self.formatTimestamp(Date())
        let config = await appState.config
        let originalFilename = req.query[String.self, at: "filename"] ?? "recording.wav"
        let ext = URL(fileURLWithPath: originalFilename).pathExtension.isEmpty
            ? "wav"
            : URL(fileURLWithPath: originalFilename).pathExtension
        let savedFilename = "\(timestamp)_\(config.filenamePrefix).\(ext)"

        // Save audio file
        let audioDir = URL(fileURLWithPath: config.audioSaveDirectory)
        let audioFileURL = audioDir.appendingPathComponent(savedFilename)

        let fm = FileManager.default
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
        try bytes.write(to: audioFileURL)

        let uploadId = UUID().uuidString

        let record = UploadRecord(
            id: uploadId,
            filename: savedFilename,
            deviceName: deviceName,
            receivedAt: Date(),
            fileSize: Int64(bytes.count),
            transcriptionStatus: config.autoTranscribe ? .queued : .skipped
        )

        await appState.addUpload(record)

        // Clear active upload indicator
        await MainActor.run {
            appState.activePhoneUpload = nil
        }

        req.logger.info("Received \(bytes.count) bytes from \(deviceName), saved as \(savedFilename)")
        sendReceivedNotification(deviceName: deviceName, filename: savedFilename)

        // Trigger transcription if enabled
        if config.autoTranscribe {
            Task {
                await transcribeInBackground(audioFileURL: audioFileURL, uploadId: uploadId, config: config)
            }
        }

        return UploadResponse(id: uploadId, status: "received", filename: savedFilename)
    }

    private func transcribeInBackground(audioFileURL: URL, uploadId: String, config: AppConfiguration) async {
        let backend: TranscriptionBackend

        let superWhisperPath = URL(fileURLWithPath: config.superWhisperRecordingsPath)
        let swBackend = SuperWhisperBackend(recordingsDirectory: superWhisperPath)

        if swBackend.isAvailable {
            backend = swBackend
            print("[Transcription] Using SuperWhisper backend")
        } else {
            backend = StubBackend()
            print("[Transcription] SuperWhisper not available, using stub backend")
        }

        do {
            let result = try await backend.transcribe(audioFilePath: audioFileURL)

            // Save transcription text
            let timestamp = audioFileURL.deletingPathExtension().lastPathComponent
            let textFilename = "\(timestamp).txt"
            let textDir = URL(fileURLWithPath: config.transcriptionSaveDirectory)
            let textFileURL = textDir.appendingPathComponent(textFilename)

            try FileManager.default.createDirectory(at: textDir, withIntermediateDirectories: true)
            try result.text.write(to: textFileURL, atomically: true, encoding: .utf8)

            // Update status
            await updateUploadStatus(uploadId: uploadId, status: .completed)

            // Optionally delete audio
            if config.autoDeleteAudioAfterTranscription {
                try? FileManager.default.removeItem(at: audioFileURL)
            }
        } catch {
            print("[Transcription] Failed for \(audioFileURL.lastPathComponent): \(error)")
            await updateUploadStatus(uploadId: uploadId, status: .failed)
        }
    }

    private func updateUploadStatus(uploadId: String, status: UploadRecord.TranscriptionStatus) async {
        if let idx = await appState.recentUploads.firstIndex(where: { $0.id == uploadId }) {
            await MainActor.run {
                appState.recentUploads[idx].transcriptionStatus = status
            }
        }
    }

    private func sendReceivedNotification(deviceName: String, filename: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Audio Received"
        content.body = "From \(deviceName)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "localflow-received-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: date)
    }
}
