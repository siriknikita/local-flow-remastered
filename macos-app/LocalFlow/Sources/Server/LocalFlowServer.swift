import Vapor
import Foundation

final class LocalFlowServer: Sendable {
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

        // Health check
        app.get("api", "health") { req -> String in
            return "{\"status\":\"ok\",\"name\":\"\(Host.current().localizedName ?? "Mac")\"}"
        }

        // Pairing endpoints
        app.post("api", "pair", use: pairingController.initiatePairing)
        app.post("api", "pair", "confirm", use: pairingController.confirmPairing)

        // Upload endpoint (requires auth)
        app.on(.POST, "api", "upload", body: .collect(maxSize: "50mb"), use: uploadController.handleUpload)

        self.app = app

        try await app.startup()
    }

    func stop() {
        app?.shutdown()
        app = nil
    }
}
