import Foundation

final class BonjourAdvertiser: NSObject, NetServiceDelegate {
    private var netService: NetService?
    private let port: Int

    init(port: Int) {
        self.port = port
        super.init()
    }

    func startAdvertising() {
        let service = NetService(
            domain: "",
            type: "_localflow._tcp.",
            name: Host.current().localizedName ?? "LocalFlow Mac",
            port: Int32(port)
        )

        let txtData: [String: Data] = [
            "name": (Host.current().localizedName ?? "Mac").data(using: .utf8)!,
            "version": "1".data(using: .utf8)!,
        ]
        service.setTXTRecord(NetService.data(fromTXTRecord: txtData))
        service.delegate = self
        service.publish()
        self.netService = service
    }

    func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    // MARK: - NetServiceDelegate

    func netServiceDidPublish(_ sender: NetService) {
        print("[Bonjour] Published service: \(sender.name) on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("[Bonjour] Failed to publish: \(errorDict)")
    }
}
