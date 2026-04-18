import Foundation
import AppKit

final class SuperWhisperBackend: TranscriptionBackend {
    let name = "SuperWhisper"
    private let recordingsDirectory: URL
    private let timeoutSeconds: TimeInterval = 120

    init(recordingsDirectory: URL) {
        self.recordingsDirectory = recordingsDirectory
    }

    var isAvailable: Bool {
        // Check if SuperWhisper app exists on the system
        let workspace = NSWorkspace.shared
        if workspace.urlForApplication(withBundleIdentifier: "com.superwhisper.superwhisper") != nil {
            return true
        }
        // Fallback: check if the app can be found by name
        if workspace.urlForApplication(toOpen: URL(string: "superwhisper://")!) != nil {
            return true
        }
        return false
    }

    func transcribe(audioFilePath: URL) async throws -> TranscriptionResult {
        // Snapshot existing recording folder names
        let existingFolders = try snapshotRecordingFolders()

        print("[SuperWhisper] Opening \(audioFilePath.lastPathComponent) in SuperWhisper...")

        // Open the audio file in SuperWhisper
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [audioFilePath.path, "-a", "superwhisper"]
        try process.run()
        process.waitUntilExit()

        print("[SuperWhisper] Waiting for transcription result...")

        // Watch for new recording folder
        let result = try await waitForNewRecording(existingFolders: existingFolders)
        print("[SuperWhisper] Got result: \(result.text.prefix(80))...")
        return result
    }

    private func snapshotRecordingFolders() throws -> Set<String> {
        let contents = try FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return Set(contents.map { $0.lastPathComponent })
    }

    private func waitForNewRecording(existingFolders: Set<String>) async throws -> TranscriptionResult {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s poll interval

            let currentFolders = try snapshotRecordingFolders()
            let newFolders = currentFolders.subtracting(existingFolders)

            for folderName in newFolders {
                let metaURL = recordingsDirectory
                    .appendingPathComponent(folderName)
                    .appendingPathComponent("meta.json")

                guard FileManager.default.fileExists(atPath: metaURL.path) else {
                    continue // meta.json not yet written
                }

                // Wait a moment for the file to be fully written
                try await Task.sleep(nanoseconds: 200_000_000)

                if let result = try? parseMetadata(at: metaURL) {
                    return result
                }
            }
        }

        throw TranscriptionError.timeout
    }

    private func parseMetadata(at url: URL) throws -> TranscriptionResult {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionError.metadataParsingFailed("Invalid JSON")
        }

        guard let result = json["result"] as? String, !result.isEmpty else {
            // result field missing or empty — SuperWhisper is still processing
            throw TranscriptionError.metadataParsingFailed("Result not ready yet")
        }

        let rawResult = json["rawResult"] as? String
        let processingTime = (json["processingTime"] as? Double).map { $0 / 1000.0 }
        let modelName = json["modelName"] as? String

        return TranscriptionResult(
            text: result,
            rawText: rawResult,
            processingTime: processingTime,
            modelName: modelName
        )
    }
}
