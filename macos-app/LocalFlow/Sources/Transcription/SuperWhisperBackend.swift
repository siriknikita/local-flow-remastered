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
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier?.lowercased().contains("superwhisper") == true
        }
    }

    func transcribe(audioFilePath: URL) async throws -> TranscriptionResult {
        guard isAvailable else {
            throw TranscriptionError.superWhisperNotRunning
        }

        // Snapshot existing recording folder names
        let existingFolders = try snapshotRecordingFolders()

        // Open the audio file in SuperWhisper
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [audioFilePath.path, "-a", "superwhisper"]
        try process.run()
        process.waitUntilExit()

        // Watch for new recording folder
        let result = try await waitForNewRecording(existingFolders: existingFolders)
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

        guard let result = json["result"] as? String else {
            throw TranscriptionError.metadataParsingFailed("Missing 'result' field")
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
