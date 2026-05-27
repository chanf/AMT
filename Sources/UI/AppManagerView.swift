import SwiftUI

struct AppManagerView: View {
    let device: AndroidDevice
    let provider: FileProvider
    
    @State private var apps: [AndroidApp] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var message: String? = nil

    var filteredApps: [AndroidApp] {
        if searchText.isEmpty {
            return apps
        } else {
            return apps.filter { 
                $0.packageName.localizedCaseInsensitiveContains(searchText) || 
                ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("应用管理")
                    .font(.headline)
                Spacer()
                if let msg = message {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .transition(.opacity)
                }
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()

            if isLoading {
                ProgressView("正在加载应用列表...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredApps) {
                    TableColumn("应用名称") { app in
                        HStack {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                            Text(app.name ?? "正在查询...")
                                .foregroundColor(app.name == nil ? .secondary : .primary)
                        }
                    }
                    TableColumn("包名") { app in
                        Text(app.packageName)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    TableColumn("操作") { app in
                        Button(role: .destructive) {
                            uninstall(app: app)
                        } label: {
                            Text("卸载")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .width(60)
                }
            }
        }
        .navigationTitle("\(device.model) - 应用")
        .onAppear(perform: refresh)
        .searchable(text: $searchText, prompt: "搜索应用名称或包名...")
    }

    func refresh() {
        isLoading = true
        message = nil
        Task {
            do {
                let fetchedApps = try await provider.listApps()
                await MainActor.run {
                    self.apps = fetchedApps
                    self.isLoading = false
                }
                
                // Lazy fetch app names in background
                for i in 0..<fetchedApps.count {
                    let pkg = fetchedApps[i].packageName
                    // Add a small delay to avoid overwhelming the ADB process
                    if i > 0 && i % 5 == 0 { try? await Task.sleep(nanoseconds: 100_000_000) }
                    
                    if let name = try? await provider.fetchAppName(packageName: pkg) {
                        await MainActor.run {
                            if let currentIndex = self.apps.firstIndex(where: { $0.packageName == pkg }) {
                                self.apps[currentIndex].name = name
                            }
                        }
                    } else {
                        // If still not found, mark it so we don't show "querying" forever
                        await MainActor.run {
                            if let currentIndex = self.apps.firstIndex(where: { $0.packageName == pkg }) {
                                if self.apps[currentIndex].name == nil {
                                    self.apps[currentIndex].name = pkg // Fallback
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.message = "加载失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func uninstall(app: AndroidApp) {
        message = "正在卸载 \(app.packageName)..."
        Task {
            do {
                try await provider.uninstallApp(packageName: app.packageName)
                await MainActor.run {
                    self.message = "卸载成功"
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.message = "卸载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
