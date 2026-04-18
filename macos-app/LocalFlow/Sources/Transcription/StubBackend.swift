import Foundation

struct StubBackend: TranscriptionBackend {
    let name = "Stub (No Transcription)"
    let isAvailable = true

    func transcribe(audioFilePath: URL) async throws -> TranscriptionResult {
        print("[StubBackend] Audio saved at \(audioFilePath.path) — transcription not available")

        return TranscriptionResult(
            text: "[Audio saved — manual transcription required]\nFile: \(audioFilePath.lastPathComponent)",
            rawText: nil,
            processingTime: nil,
            modelName: nil
        )
    }
}
