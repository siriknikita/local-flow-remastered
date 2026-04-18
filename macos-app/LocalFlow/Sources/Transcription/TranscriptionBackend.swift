import Foundation

struct TranscriptionResult {
    let text: String
    let rawText: String?
    let processingTime: TimeInterval?
    let modelName: String?
}

protocol TranscriptionBackend {
    var name: String { get }
    var isAvailable: Bool { get }
    func transcribe(audioFilePath: URL) async throws -> TranscriptionResult
}

enum TranscriptionError: LocalizedError {
    case superWhisperNotRunning
    case timeout
    case noResultFound
    case metadataParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .superWhisperNotRunning:
            return "SuperWhisper is not running"
        case .timeout:
            return "Transcription timed out waiting for SuperWhisper result"
        case .noResultFound:
            return "No transcription result found in SuperWhisper recordings"
        case .metadataParsingFailed(let detail):
            return "Failed to parse SuperWhisper metadata: \(detail)"
        }
    }
}
