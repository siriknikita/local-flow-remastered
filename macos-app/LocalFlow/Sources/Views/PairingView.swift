import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let pairing = appState.pendingPairing, !pairing.isExpired {
                    pendingPairingCard(pairing)
                }

                pairedDevicesCard
            }
            .padding(24)
        }
        .navigationTitle("Pairing")
    }

    // MARK: - Pending Pairing

    private func pendingPairingCard(_ pairing: PairingRequest) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.orange)
                Text("\(pairing.deviceName) wants to pair")
                    .font(.headline)
                Spacer()
            }

            Text(pairing.code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .kerning(8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

            Text("Enter this code on your Android device")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Paired Devices

    private var pairedDevicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paired Devices")
                .font(.headline)

            if appState.pairedDevices.isEmpty {
                Text("No paired devices. Open LocalFlow on your Android device to pair.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(appState.pairedDevices) { device in
                    deviceRow(device)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func deviceRow(_ device: PairedDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName)
                    .font(.body)
                Text("Paired \(device.pairedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Remove") {
                appState.removePairedDevice(device)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}
