import SwiftUI

enum ViewMode {
    case fileBrowser
    case appManager
}

struct MainView: View {
    @StateObject var deviceManager = UnifiedDeviceManager()
    @State private var selectedDevice: AndroidDevice?
    @State private var selectedFile: AndroidFile? = nil
    @State private var selectedApp: AndroidApp? = nil
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
                    Group {
                        if viewMode == .fileBrowser {
                            FileBrowserView(device: device, externalTargetPath: $targetPath, selectedFile: $selectedFile)
                                .id(device.id)
                        } else {
                            if let provider = getProvider(for: device) {
                                AppManagerView(device: device, provider: provider, selectedApp: $selectedApp)
                                    .id("\(device.id)-apps")
                            }
                        }
                    }
                    
                    if viewMode == .fileBrowser, let file = selectedFile, (file.isImage || file.isVideo) {
                        Divider()
                        FilePreviewPane(file: file, provider: getProvider(for: device))
                            .frame(width: 300)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    if viewMode == .appManager, let app = selectedApp {
                        Divider()
                        AppDetailPane(app: app, provider: getProvider(for: device)) {
                            uninstall(app: app, device: device)
                        }
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: selectedFile)
                .animation(.spring(), value: selectedApp)
                .animation(.default, value: viewMode)
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
        .onAppear {
            deviceManager.startDiscovery()
        }
        .onChange(of: selectedDevice) { _ in
            selectedFile = nil
            selectedApp = nil
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

    private func uninstall(app: AndroidApp, device: AndroidDevice) {
        guard let provider = getProvider(for: device) else { return }
        Task {
            do {
                try await provider.uninstallApp(packageName: app.packageName)
                await MainActor.run {
                    self.selectedApp = nil
                    // Note: Ideally we'd trigger a refresh in AppManagerView here.
                }
            } catch {
                print("Uninstall failed: \(error)")
            }
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
                }
                .padding(.vertical, 8)
            }
            
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

                Section("应用管理") {
                    Button {
                        viewMode = .appManager
                    } label: {
                        Label("应用列表", systemImage: "apps.iphone.badge.plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("安卓设备")
        .listStyle(.sidebar)
    }
}
