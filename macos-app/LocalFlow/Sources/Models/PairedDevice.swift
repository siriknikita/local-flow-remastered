import Foundation

struct PairedDevice: Codable, Identifiable {
    let deviceId: String
    let deviceName: String
    let token: String
    let pairedAt: Date

    var id: String { deviceId }
}

struct PairingRequest: Identifiable {
    let id = UUID()
    let deviceId: String
    let deviceName: String
    let code: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }
}

final class DeviceStore: Codable {
    var devices: [PairedDevice]

    init() {
        self.devices = []
    }

    static let storeURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LocalFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("paired_devices.json")
    }()

    static func load() -> DeviceStore {
        guard let data = try? Data(contentsOf: storeURL) else {
            return DeviceStore()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let store = try? decoder.decode(DeviceStore.self, from: data) else {
            return DeviceStore()
        }
        return store
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self) {
            try? data.write(to: Self.storeURL)
        }
    }
}
