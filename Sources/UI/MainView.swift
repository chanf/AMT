import SwiftUI

struct MainView: View {
    @StateObject var deviceManager = UnifiedDeviceManager()
    @State private var selectedDevice: AndroidDevice?
    @State private var targetPath: String? = nil
    @State private var navigationPath = [String]() // Breadcrumbs

    var body: some View {
        NavigationSplitView {
            DeviceSidebar(selectedDevice: $selectedDevice, targetPath: $targetPath)
                .environmentObject(deviceManager)
        } detail: {
            if let device = selectedDevice {
                FileBrowserView(device: device, externalTargetPath: $targetPath)
                    .id(device.id)
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
    @Binding var targetPath: String?

    var body: some View {
        List(selection: $selectedDevice) {
            Section("设备列表") {
                ForEach(deviceManager.connectedDevices) { device in
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
                    .tag(device as AndroidDevice?)
                }
            }

            if selectedDevice != nil {
                Section("快捷连接") {
                    Button {
                        targetPath = "/sdcard/DCIM"
                    } label: {
                        Label("相册", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        targetPath = "/sdcard/Download"
                    } label: {
                        Label("下载", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        targetPath = "/sdcard"
                    } label: {
                        Label("内部存储", systemImage: "internaldrive")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("安卓设备")
        .listStyle(.sidebar)
    }
}

