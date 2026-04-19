import Vapor
import Foundation

struct TranscriptController: Sendable {
    let appState: AppState

    struct TranscriptItem: Content {
        let id: String
        let filename: String
        let text: String
        let createdAt: String
    }

    struct TranscriptsResponse: Content {
        let transcripts: [TranscriptItem]
        let serverTime: String
    }

    func listTranscripts(req: Request) async throws -> TranscriptsResponse {
        // Validate auth token
        guard let authHeader = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization token")
        }
        guard await appState.isTokenValid(authHeader.token) else {
            throw Abort(.unauthorized, reason: "Invalid authorization token")
        }

        let config = await appState.config
        let transcriptionDir = URL(fileURLWithPath: config.transcriptionSaveDirectory)

        let since = req.query[String.self, at: "since"]
        let limit = req.query[Int.self, at: "limit"] ?? 20
        let cappedLimit = min(max(limit, 1), 50)

        let sinceDate: Date? = since.flatMap { Self.parseISO8601($0) }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: transcriptionDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return TranscriptsResponse(transcripts: [], serverTime: Self.formatISO8601(Date()))
        }

        let txtFiles = files.filter { $0.pathExtension == "txt" }

        var items: [(date: Date, url: URL)] = txtFiles.compactMap { url in
            let stem = url.deletingPathExtension().lastPathComponent
            if let date = Self.parseTimestamp(stem) {
                return (date, url)
            }
            // Fallback to file modification date
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date {
                return (modDate, url)
            }
            return nil
        }

        // Filter by since date
        if let sinceDate {
            items = items.filter { $0.date > sinceDate }
        }

        // Sort newest first
        items.sort { $0.date > $1.date }

        // Apply limit
        let limited = items.prefix(cappedLimit)

        let transcripts: [TranscriptItem] = limited.compactMap { item in
            guard let text = try? String(contentsOf: item.url, encoding: .utf8) else { return nil }
            let stem = item.url.deletingPathExtension().lastPathComponent
            return TranscriptItem(
                id: stem,
                filename: item.url.lastPathComponent,
                text: text,
                createdAt: Self.formatISO8601(item.date)
            )
        }

        return TranscriptsResponse(
            transcripts: transcripts,
            serverTime: Self.formatISO8601(Date())
        )
    }

    // Parse the filename timestamp format: yyyy-MM-dd_HH-mm-ss
    // Filenames look like "2026-04-18_15-30-00_localflow.txt" — extract first 19 chars for timestamp
    private static func parseTimestamp(_ stem: String) -> Date? {
        guard stem.count >= 19 else { return nil }
        let timestampStr = String(stem.prefix(19))

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.timeZone = TimeZone.current
        return f.date(from: timestampStr)
    }

    private static func formatISO8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}
