import Vapor
import Foundation
import UserNotifications

struct PairingController: Sendable {
    let appState: AppState

    struct PairRequest: Content {
        let deviceId: String
        let deviceName: String
    }

    struct PairResponse: Content {
        let status: String
        let message: String
        let token: String?
        let serverName: String?

        init(status: String, message: String, token: String? = nil, serverName: String? = nil) {
            self.status = status
            self.message = message
            self.token = token
            self.serverName = serverName
        }
    }

    struct ConfirmRequest: Content {
        let deviceId: String
        let code: String
    }

    struct ConfirmResponse: Content {
        let token: String
        let serverName: String
    }

    func initiatePairing(req: Request) async throws -> PairResponse {
        let pairReq = try req.content.decode(PairRequest.self)

        // Auto-accept known devices — return existing token
        if let existing = await appState.pairedDevices.first(where: { $0.deviceId == pairReq.deviceId }) {
            req.logger.info("Auto-accepted known device \(pairReq.deviceName)")
            let serverName = Host.current().localizedName ?? "Mac"
            return PairResponse(
                status: "already_paired",
                message: "Device reconnected",
                token: existing.token,
                serverName: serverName
            )
        }

        // Generate 6-digit pairing code
        let code = String(format: "%06d", Int.random(in: 0...999999))

        let request = PairingRequest(
            deviceId: pairReq.deviceId,
            deviceName: pairReq.deviceName,
            code: code,
            expiresAt: Date().addingTimeInterval(300) // 5 min expiry
        )

        await MainActor.run {
            appState.pendingPairing = request
            appState.lastEvent = "Pairing request from \(pairReq.deviceName)"
        }

        sendPairingNotification(deviceName: pairReq.deviceName, code: code)

        req.logger.info("Pairing initiated for \(pairReq.deviceName), code: \(code)")

        return PairResponse(status: "pending", message: "Enter the code shown on your Mac")
    }

    func confirmPairing(req: Request) async throws -> ConfirmResponse {
        let confirmReq = try req.content.decode(ConfirmRequest.self)

        guard let pending = await appState.pendingPairing else {
            throw Abort(.badRequest, reason: "No pending pairing request")
        }

        guard !pending.isExpired else {
            await MainActor.run { appState.pendingPairing = nil }
            throw Abort(.gone, reason: "Pairing code expired")
        }

        guard pending.deviceId == confirmReq.deviceId else {
            throw Abort(.badRequest, reason: "Device ID mismatch")
        }

        guard pending.code == confirmReq.code else {
            throw Abort(.forbidden, reason: "Invalid pairing code")
        }

        // Generate auth token
        let token = UUID().uuidString

        let device = PairedDevice(
            deviceId: confirmReq.deviceId,
            deviceName: pending.deviceName,
            token: token,
            pairedAt: Date()
        )

        await appState.addPairedDevice(device)
        await MainActor.run {
            appState.pendingPairing = nil
            appState.lastEvent = "Paired with \(pending.deviceName)"
        }

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["localflow-pairing"])

        let serverName = Host.current().localizedName ?? "Mac"
        req.logger.info("Paired with \(pending.deviceName)")

        return ConfirmResponse(token: token, serverName: serverName)
    }

    private func sendPairingNotification(deviceName: String, code: String) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                print("[Pairing] Notification permission denied")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Pairing Code"
            content.subtitle = deviceName
            content.body = code
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "localflow-pairing",
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }
}
