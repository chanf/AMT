import SwiftUI

struct AppManagerView: View {
    let device: AndroidDevice
    let provider: FileProvider
    @Binding var selectedApp: AndroidApp?
    
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
                List {
                    Section {
                        ForEach(0..<filteredApps.count, id: \.self) { index in
                            let app = filteredApps[index]
                            HStack {
                                Image(systemName: "app.dashed")
                                    .foregroundColor(.secondary)
                                Text(app.name ?? app.packageName)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
                            .onTapGesture(count: 2) {
                                self.selectedApp = app
                            }
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
                
                // Concurrent fetch app names (minimal details for list)
                try await withThrowingTaskGroup(of: (String, String?).self) { group in
                    let maxConcurrentPulls = 3
                    var currentIndex = 0
                    
                    func addNextTask() {
                        if currentIndex < fetchedApps.count {
                            let app = fetchedApps[currentIndex]
                            group.addTask {
                                // For the list, we just want the name. 
                                // In the future, we could have a fetchAppNameOnly method, 
                                // but for now, let's reuse fetchAppDetails (it caches name).
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
}
