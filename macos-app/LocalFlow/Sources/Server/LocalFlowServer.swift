import Vapor
import Foundation

final class LocalFlowServer: @unchecked Sendable {
    private var app: Application?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func start(port: Int) async throws {
        let app = try await Application.make(.production)
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = port

        // Allow large uploads (50MB)
        app.routes.defaultMaxBodySize = "50mb"

        let uploadController = UploadController(appState: appState)
        let pairingController = PairingController(appState: appState)
        let transcriptController = TranscriptController(appState: appState)

        // Health check
        app.get("api", "health") { req -> String in
            return "{\"status\":\"ok\",\"name\":\"\(Host.current().localizedName ?? "Mac")\"}"
        }

        // Status endpoint for phone polling
        let statusAppState = appState
        app.get("api", "status") { req -> String in
            let stopRequested = await statusAppState.stopPhoneRequested
            if stopRequested {
                await statusAppState.clearPhoneStop()
            }
            return "{\"stopRequested\":\(stopRequested)}"
        }

        // Recording state sync — phone notifies Mac when it starts/stops recording
        app.post("api", "recording") { req -> String in
            guard let authHeader = req.headers.bearerAuthorization else {
                throw Abort(.unauthorized)
            }
            guard await statusAppState.isTokenValid(authHeader.token) else {
                throw Abort(.unauthorized)
            }
            let deviceName = await statusAppState.deviceName(forToken: authHeader.token) ?? "Phone"

            struct RecordingBody: Content {
                let recording: Bool
            }
            let body = try req.content.decode(RecordingBody.self)

            await MainActor.run {
                statusAppState.setPhoneRecording(deviceName: deviceName, isRecording: body.recording)
            }
            return "{\"status\":\"ok\"}"
        }

        // Pairing endpoints
        app.post("api", "pair", use: pairingController.initiatePairing)
        app.post("api", "pair", "confirm", use: pairingController.confirmPairing)

        // Upload endpoint (requires auth)
        app.on(.POST, "api", "upload", body: .collect(maxSize: "50mb"), use: uploadController.handleUpload)

        // Transcripts endpoint (requires auth)
        app.get("api", "transcripts", use: transcriptController.listTranscripts)

        self.app = app

        try await app.startup()
    }

    func stop() {
        Task {
            try? await app?.asyncShutdown()
            app = nil
        }
    }
}
