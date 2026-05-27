import SwiftUI

struct AppManagerView: View {
    let device: AndroidDevice
    let provider: FileProvider
    @Binding var selectedAppIDs: Set<String>
    
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

    var primarySelectedApp: AndroidApp? {
        if let firstID = selectedAppIDs.first {
            return apps.first(where: { $0.packageName == firstID })
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
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
                    List {
                        Section {
                            ForEach(0..<filteredApps.count, id: \.self) { index in
                                let app = filteredApps[index]
                                Button(action: {
                                    let flags = NSEvent.modifierFlags
                                    if flags.contains(.command) {
                                        if selectedAppIDs.contains(app.packageName) {
                                            selectedAppIDs.remove(app.packageName)
                                        } else {
                                            selectedAppIDs.insert(app.packageName)
                                        }
                                    } else {
                                        selectedAppIDs = [app.packageName]
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "app.dashed")
                                            .foregroundColor(.secondary)
                                        Text(app.name ?? app.packageName)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    selectedAppIDs.contains(app.packageName) ? 
                                    Color.blue.opacity(0.15) : 
                                    Color.clear
                                )
                                .listRowInsets(EdgeInsets())
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    self.selectedAppIDs = [app.packageName]
                                })
                            }
                        } header: {
                            Text("应用")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.inset)
                }
            }

            // Integrated Detail Pane
            if let primary = primarySelectedApp {
                Divider()
                AppDetailPane(app: primary, provider: provider) {
                    uninstall(app: primary)
                }
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(), value: primary.packageName)
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
                
                try await withThrowingTaskGroup(of: (String, String?).self) { group in
                    let maxConcurrentPulls = 3
                    var currentIndex = 0
                    
                    func addNextTask() {
                        if currentIndex < fetchedApps.count {
                            let app = fetchedApps[currentIndex]
                            group.addTask {
                                let detailed = try? await provider.fetchAppDetails(app: app)
                                return (app.packageName, detailed?.name)
                            }
                            currentIndex += 1
                        }
                    }
                    
                    for _ in 0..<min(maxConcurrentPulls, fetchedApps.count) { addNextTask() }
                    
                    while let (pkg, name) = try await group.next() {
                        await MainActor.run {
                            if let i = self.apps.firstIndex(where: { $0.packageName == pkg }) {
                                self.apps[i].name = name
                            }
                        }
                        addNextTask()
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
                    self.selectedAppIDs.remove(app.packageName)
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
