import SwiftUI

struct MainView: View {
    @StateObject var deviceManager = UnifiedDeviceManager()
    @State private var selectedDevice: AndroidDevice?
    @State private var navigationPath = [String]() // Breadcrumbs

    var body: some View {
        NavigationSplitView {
            DeviceSidebar(selectedDevice: $selectedDevice)
                .environmentObject(deviceManager)
        } detail: {
            if let device = selectedDevice {
                FileBrowserView(device: device)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a Device")
                        .font(.title2)
                    Text("Connect an Android device via USB to start browsing.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            deviceManager.startDiscovery()
        }
    }
}

struct DeviceSidebar: View {
    @EnvironmentObject var deviceManager: UnifiedDeviceManager
    @Binding var selectedDevice: AndroidDevice?

    var body: some View {
        List(deviceManager.connectedDevices, selection: $selectedDevice) { device in
            NavigationLink(value: device) {
                Label {
                    VStack(alignment: .leading) {
                        Text(device.model)
                        Text(device.connectionType.rawValue.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "phone.fill")
                }
            }
        }
        .navigationTitle("Devices")
    }
}
