import SwiftUI

struct MenuBarControlsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var bassBinding: Binding<Double> {
        Binding(
            get: { Double(model.state.clearBassLevel ?? 0) },
            set: { model.setClearBass(Int($0.rounded())) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "headphones").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(model.state.connected ? "MDR-XB950N1" : "XB950 Control").font(.headline)
                    if let battery = model.state.battery, model.state.connected {
                        Text("Battery \(battery)%\(model.state.charging ? " · Charging" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(model.state.connected ? "Reading headphones…" : "Not connected")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if model.state.connected {
                Toggle("Noise cancelling", isOn: Binding(
                    get: { model.state.noiseCancelling ?? false },
                    set: model.setNoiseCancelling
                ))
                .disabled(model.state.noiseCancelling == nil)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("CLEAR BASS")
                        Spacer()
                        Text(String(format: "%+d", model.state.clearBassLevel ?? 0)).monospacedDigit()
                    }
                    Slider(value: bassBinding, in: -10...10, step: 1)
                        .disabled(model.state.clearBassLevel == nil)
                }

                Picker("Surround", selection: Binding(
                    get: { model.state.surround ?? .off },
                    set: model.setSurround
                )) {
                    ForEach(SurroundMode.allCases) { mode in Text(mode.label).tag(mode) }
                }
                .disabled(model.state.surround == nil)
            }

            Divider()

            HStack {
                Button("Open XB950 Control") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                if model.state.connected {
                    Button("Refresh") { model.refreshState() }
                } else {
                    Button("Find Headphones") { model.refreshDevices() }
                }
            }
        }
        .padding(16)
        .frame(width: 310)
    }
}
