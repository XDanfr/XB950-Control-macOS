import SwiftUI

@main
struct XB950ControlApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("XB950 Control", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 680, minHeight: 560)
        }
        .defaultSize(width: 760, height: 660)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Refresh from Headphones") { model.refreshState() }
                    .keyboardShortcut("r")
                    .disabled(!model.state.connected)
            }
        }

        MenuBarExtra {
            MenuBarControlsView()
                .environmentObject(model)
        } label: {
            Label(menuBarTitle, systemImage: model.state.noiseCancelling == true
                  ? "headphones.circle.fill" : "headphones.circle")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        guard model.state.connected else { return "XB950" }
        if let battery = model.state.battery { return "\(battery)%" }
        return "XB950"
    }
}
