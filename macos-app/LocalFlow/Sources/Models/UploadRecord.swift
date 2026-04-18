import Foundation

struct UploadRecord: Identifiable {
    let id: String
    let filename: String
    let deviceName: String
    let receivedAt: Date
    let fileSize: Int64
    var transcriptionStatus: TranscriptionStatus

    enum TranscriptionStatus: String {
        case received
        case queued
        case transcribing
        case completed
        case failed
        case skipped
    }
}
