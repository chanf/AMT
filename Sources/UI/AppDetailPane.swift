import SwiftUI

struct AppDetailPane: View {
    let app: AndroidApp?
    let provider: FileProvider?
    let onUninstall: () -> Void
    
    @State private var detailedApp: AndroidApp? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var loadingTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            if let displayApp = detailedApp ?? app {
                ScrollView {
                    VStack(spacing: 24) {
                        // App Icon
                        if isLoading {
                            ProgressView()
                                .frame(width: 100, height: 100)
                                .padding(.top, 40)
                        } else if let iconURL = displayApp.iconURL, let nsImage = NSImage(contentsOf: iconURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .cornerRadius(18)
                                .shadow(radius: 4)
                                .padding(.top, 40)
                        } else {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                        
                        // Main Info
                        VStack(spacing: 8) {
                            Text(displayApp.name ?? displayApp.packageName)
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)
                            
                            Text(displayApp.packageName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal)
                        
                        Divider().padding(.horizontal)
                        
                        // Technical Details
                        VStack(alignment: .leading, spacing: 12) {
                            detailRow(label: "版本名称", value: displayApp.versionName ?? "未知")
                            detailRow(label: "版本代码", value: displayApp.versionCode ?? "未知")
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                        
                        // Actions
                        Button(role: .destructive) {
                            onUninstall()
                        } label: {
                            Label("卸载此应用", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("双击列表中的应用查看详情")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadDetails(for: app)
        }
        .onChange(of: app) { newApp in
            loadDetails(for: newApp)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
    
    private func loadDetails(for app: AndroidApp?) {
        loadingTask?.cancel()
        loadingTask = nil
        detailedApp = nil
        errorMessage = nil
        
        guard let app = app, let provider = provider else { return }
        
        isLoading = true
        loadingTask = Task {
            do {
                let result = try await provider.fetchAppDetails(app: app)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.detailedApp = result
                        self.isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "加载详情失败: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
