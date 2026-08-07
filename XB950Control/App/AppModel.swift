import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var devices: [PairedHeadphones] = []
    @Published private(set) var state = HeadphoneState()
    @Published private(set) var isConnecting = false
    @Published var errorMessage: String?

    private let controller = HeadphoneController()
    private let lastAddressKey = "lastConnectedHeadphonesAddress"

    init() {
        controller.onState = { [weak self] state in self?.state = state }
        controller.onError = { [weak self] error in self?.errorMessage = error.localizedDescription }
        refreshDevices(autoConnect: true)
    }

    func refreshDevices(autoConnect: Bool = false) {
        devices = HeadphoneController.pairedDevices()
        guard autoConnect, !state.connected, !isConnecting else { return }
        let saved = UserDefaults.standard.string(forKey: lastAddressKey)
        if let device = devices.first(where: { $0.address == saved }) {
            connect(to: device)
        }
    }

    func connect(to device: PairedHeadphones) {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        controller.connect(to: device) { [weak self] error in
            guard let self else { return }
            self.isConnecting = false
            if let error {
                self.errorMessage = error.localizedDescription
            } else {
                UserDefaults.standard.set(device.address, forKey: self.lastAddressKey)
            }
        }
    }

    func disconnect() {
        controller.disconnect()
        isConnecting = false
    }

    func refreshState() { controller.refresh() }
    func setNoiseCancelling(_ enabled: Bool) { controller.setNoiseCancelling(enabled) }
    func setClearBass(_ level: Int) { controller.setClearBass(level) }
    func setSurround(_ mode: SurroundMode) { controller.setSurround(mode) }

    func openBluetoothSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
