import SwiftUI

enum ViewMode {
    case fileBrowser
    case appManager
    case networkManager
    case performance
}

struct MainView: View {
    @StateObject var deviceManager = UnifiedDeviceManager()
    @State private var selectedDevice: AndroidDevice?
    @State private var selectedFileIDs = Set<String>()
    @State private var selectedAppIDs = Set<String>()
    @State private var targetPath: String? = nil
    @State private var viewMode: ViewMode = .fileBrowser
    @State private var navigationPath = [String]() // Breadcrumbs

    var body: some View {
        NavigationSplitView {
            DeviceSidebar(selectedDevice: $selectedDevice, targetPath: $targetPath, viewMode: $viewMode)
                .environmentObject(deviceManager)
        } detail: {
            if let device = selectedDevice {
                HStack(spacing: 0) {
                    if viewMode == .fileBrowser {
                        FileBrowserView(device: device, externalTargetPath: $targetPath, selectedFileIDs: $selectedFileIDs)
                            .id(device.id)
                    } else if viewMode == .appManager {
                        if let provider = getProvider(for: device) {
                            AppManagerView(device: device, provider: provider, selectedAppIDs: $selectedAppIDs)
                                .id("\(device.id)-apps")
                        }
                    } else if viewMode == .performance {
                        DevicePerformanceView(device: device)
                            .id("\(device.id)-performance")
                    } else {
                        NetworkManagerView()
                    }
                }
                .animation(.default, value: viewMode)
            } else {
                if viewMode == .networkManager {
                    NetworkManagerView()
                } else {
                    VStack(spacing: 20) {
                        AppIcon(size: 100)
                        VStack(spacing: 8) {
                            Text("选择一个设备")
                                .font(.title2)
                            Text("通过 USB 线连接安卓设备以开始浏览")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            deviceManager.startDiscovery()
        }
        .onChange(of: selectedDevice) { _ in
            selectedFileIDs.removeAll()
            selectedAppIDs.removeAll()
        }
    }
    
    private func getProvider(for device: AndroidDevice?) -> FileProvider? {
        guard let device = device else { return nil }
        if device.connectionType == .adb {
            return ADBFileProvider(device: device)
        } else {
            return MTPFileProvider(device: device)
        }
    }
}

struct DeviceSidebar: View {
    @EnvironmentObject var deviceManager: UnifiedDeviceManager
    @Binding var selectedDevice: AndroidDevice?
    @Binding var targetPath: String?
    @Binding var viewMode: ViewMode

    var body: some View {
        List(selection: $selectedDevice) {
            Section {
                HStack {
                    AppIcon(size: 40)
                    VStack(alignment: .leading) {
                        Text("AndroidFile")
                            .font(.headline)
                        Text("文件管理器")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        deviceManager.startDiscovery()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("刷新设备列表")
                }
                .padding(.vertical, 8)
            }
            
            Section("设备列表") {
                ForEach(deviceManager.connectedDevices) { device in
                    NavigationLink(value: device) {
                        Label {
                            VStack(alignment: .leading) {
                                Text(device.model)
                                Text(device.isWireless ? "WI-FI" : device.connectionType.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: device.isWireless ? "wifi" : "phone.fill")
                        }
                    }
                    .tag(device as AndroidDevice?)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewMode = .fileBrowser
                    })
                }
            }

            if selectedDevice != nil {
                Section("监控与管理") {
                    Button {
                        viewMode = .performance
                    } label: {
                        Label("性能面板", systemImage: "chart.bar.xaxis")
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewMode = .appManager
                    } label: {
                        Label("应用列表", systemImage: "apps.iphone.badge.plus")
                    }
                    .buttonStyle(.plain)
                }

                Section("快捷连接") {
                    Button {
                        viewMode = .fileBrowser
                        targetPath = "/sdcard/DCIM"
                    } label: {
                        Label("相册", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewMode = .fileBrowser
                        targetPath = "/sdcard/Download"
                    } label: {
                        Label("下载", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewMode = .fileBrowser
                        targetPath = "/sdcard"
                    } label: {
                        Label("内部存储", systemImage: "internaldrive")
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("网络连接") {
                Button {
                    viewMode = .networkManager
                } label: {
                    Label("远程管理", systemImage: "network")
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("安卓设备")
        .listStyle(.sidebar)
    }
}
