import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.state.connected {
                    ConnectedView()
                } else {
                    DevicePickerView()
                }
            }
            .navigationTitle("XB950 Control")
            .toolbar {
                if model.state.connected {
                    ToolbarItemGroup {
                        Button("Refresh", systemImage: "arrow.clockwise") { model.refreshState() }
                        Button("Disconnect") { model.disconnect() }
                    }
                }
            }
        }
        .alert("XB950 Control", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }
}

private struct DevicePickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "headphones")
                .font(.system(size: 70, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Connect your MDR-XB950N1")
                    .font(.largeTitle.bold())
                Text("Pair the headphones in Bluetooth settings, turn them on, then connect here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                if model.devices.isEmpty {
                    ContentUnavailableView(
                        "No paired headphones",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Pair an MDR-XB950N1 in System Settings, then refresh the list.")
                    )
                    .frame(maxWidth: 520, minHeight: 150)
                } else {
                    ForEach(model.devices) { device in
                        HStack(spacing: 14) {
                            Image(systemName: "headphones")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name).font(.headline)
                                Text(device.address).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Connect") { model.connect(to: device) }
                                .buttonStyle(.glassProminent)
                                .disabled(model.isConnecting)
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .frame(maxWidth: 540)

            if model.isConnecting {
                ProgressView("Opening Sony control service…")
                    .controlSize(.small)
            }

            HStack {
                Button("Open Bluetooth Settings") { model.openBluetoothSettings() }
                Button("Refresh") { model.refreshDevices() }
            }
            Spacer()
        }
        .padding(34)
    }
}

private struct ConnectedView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                DeviceHeader(state: model.state)
                SoundControlsView()
                HeadphoneInformationView(state: model.state)
            }
            .padding(28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct DeviceHeader: View {
    let state: HeadphoneState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.model.isEmpty ? "MDR-XB950N1" : state.model).font(.title2.bold())
                Text(state.address).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = state.battery {
                HStack(spacing: 7) {
                    Image(systemName: state.charging ? "battery.100percent.bolt" : batterySymbol(battery))
                    Text("\(battery)%").font(.title3.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Battery \(battery) percent\(state.charging ? ", charging" : "")")
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    }

    private func batterySymbol(_ value: Int) -> String {
        switch value {
        case 76...: "battery.100percent"
        case 51...: "battery.75percent"
        case 26...: "battery.50percent"
        case 11...: "battery.25percent"
        default: "battery.0percent"
        }
    }
}

private struct SoundControlsView: View {
    @EnvironmentObject private var model: AppModel

    private var bassBinding: Binding<Double> {
        Binding(
            get: { Double(model.state.clearBassLevel ?? 0) },
            set: { model.setClearBass(Int($0.rounded())) }
        )
    }

    var body: some View {
        GroupBox("Sound") {
            VStack(spacing: 0) {
                LabeledContent {
                    Toggle("Noise cancelling", isOn: Binding(
                        get: { model.state.noiseCancelling ?? false },
                        set: model.setNoiseCancelling
                    ))
                    .labelsHidden()
                    .disabled(model.state.noiseCancelling == nil)
                } label: {
                    SettingLabel("Noise cancelling", detail: "Reduce steady ambient noise", icon: "waveform.badge.minus")
                }
                .padding(.vertical, 14)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SettingLabel("CLEAR BASS level", detail: "Sony Extra Bass intensity", icon: "waveform")
                        Spacer()
                        Text(String(format: "%+d", model.state.clearBassLevel ?? 0))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: bassBinding, in: -10...10, step: 1) {
                        Text("CLEAR BASS")
                    } minimumValueLabel: {
                        Text("−10").font(.caption).monospacedDigit()
                    } maximumValueLabel: {
                        Text("+10").font(.caption).monospacedDigit()
                    }
                    .disabled(model.state.clearBassLevel == nil)
                    .accessibilityValue("\(model.state.clearBassLevel ?? 0)")
                }
                .padding(.vertical, 14)

                Divider()

                LabeledContent {
                    Picker("Surround", selection: Binding(
                        get: { model.state.surround ?? .off },
                        set: model.setSurround
                    )) {
                        ForEach(SurroundMode.allCases) { mode in Text(mode.label).tag(mode) }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .disabled(model.state.surround == nil)
                } label: {
                    SettingLabel("Surround (VPT)", detail: "Sony virtual acoustic environments", icon: "theatermasks")
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct SettingLabel: View {
    let title: String
    let detail: String
    let icon: String

    init(_ title: String, detail: String, icon: String) {
        self.title = title
        self.detail = detail
        self.icon = icon
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 22)
        }
    }
}

private struct HeadphoneInformationView: View {
    let state: HeadphoneState

    var body: some View {
        GroupBox("Headphones") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 13) {
                InfoRow(label: "Model", value: state.model.isEmpty ? "Loading…" : state.model)
                Divider().gridCellColumns(2)
                InfoRow(label: "Firmware", value: state.firmware.isEmpty ? "Loading…" : state.firmware)
                Divider().gridCellColumns(2)
                InfoRow(label: "Protocol", value: state.protocolVersion.map { "MDR \($0)" } ?? "Loading…")
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).textSelection(.enabled)
        }
    }
}

#Preview("Connected") {
    ConnectedPreview()
}

@MainActor
private struct ConnectedPreview: View {
    @StateObject private var model = AppModel()

    var body: some View {
        DeviceHeader(state: .preview)
            .padding()
            .frame(width: 700)
    }
}
