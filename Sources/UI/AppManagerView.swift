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
            return apps.filter { $0.packageName.localizedCaseInsensitiveContains(searchText) }
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
                List(filteredApps) { app in
                    HStack {
                        Image(systemName: "app.dashed")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text(app.packageName)
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            uninstall(app: app)
                        } label: {
                            Text("卸载")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("\(device.model) - 应用")
        .onAppear(perform: refresh)
        .searchable(text: $searchText, prompt: "搜索包名...")
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
