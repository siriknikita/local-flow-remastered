import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isServerRunning = false
    @Published var serverPort: Int = 8080
    @Published var lastEvent: String = ""
    @Published var recentUploads: [UploadRecord] = []
    @Published var pairedDevices: [PairedDevice] = []
    @Published var pendingPairing: PairingRequest?

    let config: AppConfiguration
    let deviceStore: DeviceStore
    private var server: LocalFlowServer?
    private var bonjourAdvertiser: BonjourAdvertiser?

    init() {
        self.config = AppConfiguration.load()
        self.deviceStore = DeviceStore.load()
        self.pairedDevices = deviceStore.devices
    }

    func startServer() {
        guard !isServerRunning else { return }

        let server = LocalFlowServer(appState: self)
        self.server = server

        Task {
            do {
                try await server.start(port: serverPort)
                isServerRunning = true
                lastEvent = "Server started on port \(serverPort)"

                let advertiser = BonjourAdvertiser(port: serverPort)
                advertiser.startAdvertising()
                self.bonjourAdvertiser = advertiser
            } catch {
                lastEvent = "Failed to start server: \(error.localizedDescription)"
            }
        }
    }

    func stopServer() {
        server?.stop()
        server = nil
        bonjourAdvertiser?.stopAdvertising()
        bonjourAdvertiser = nil
        isServerRunning = false
        lastEvent = "Server stopped"
    }

    func addUpload(_ record: UploadRecord) {
        recentUploads.insert(record, at: 0)
        if recentUploads.count > 50 {
            recentUploads = Array(recentUploads.prefix(50))
        }
    }

    func addPairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.deviceId == device.deviceId }
        pairedDevices.append(device)
        deviceStore.devices = pairedDevices
        deviceStore.save()
    }

    func removePairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.deviceId == device.deviceId }
        deviceStore.devices = pairedDevices
        deviceStore.save()
    }

    func isTokenValid(_ token: String) -> Bool {
        pairedDevices.contains { $0.token == token }
    }

    func deviceName(forToken token: String) -> String? {
        pairedDevices.first { $0.token == token }?.deviceName
    }
}
