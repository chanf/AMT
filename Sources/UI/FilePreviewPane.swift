import SwiftUI

struct FilePreviewPane: View {
    let file: AndroidFile?
    let provider: FileProvider?
    
    @State private var previewURL: URL? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack {
            if let file = file {
                ScrollView {
                    VStack(spacing: 20) {
                        // Icon or Image
                        if file.isImage {
                            imagePreviewSection(for: file)
                        } else {
                            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 80))
                                .foregroundColor(file.isDirectory ? .blue : .secondary)
                                .padding(.top, 40)
                        }
                        
                        // File info
                        VStack(spacing: 8) {
                            Text(file.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            if !file.isDirectory {
                                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let date = file.modificationDate {
                                Text("修改日期: \(date.formatted())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow(label: "路径", value: file.path)
                            infoRow(label: "类型", value: file.isDirectory ? "文件夹" : (file.extensionName.uppercased() + " 文件"))
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择一个文件以查看预览")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 250)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadPreview(for: file)
        }
        .onChange(of: file) { newFile in
            loadPreview(for: newFile)
        }
    }
    
    @ViewBuilder
    private func imagePreviewSection(for file: AndroidFile) -> some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if let url = previewURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .padding()
                    .shadow(radius: 4)
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                }
                .frame(height: 200)
            } else {
                // Initial state
                Color.clear.frame(height: 200)
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
    
    private func loadPreview(for file: AndroidFile?) {
        previewURL = nil
        errorMessage = nil
        
        guard let file = file, file.isImage, let provider = provider else { return }
        
        print("PreviewPane: Starting load for \(file.name)")
        isLoading = true
        Task {
            do {
                if let url = try await provider.fetchPreviewData(for: file) {
                    let data = try Data(contentsOf: url)
                    print("PreviewPane: Read \(data.count) bytes from local temp file")
                    
                    if let nsImage = NSImage(data: data) {
                        print("PreviewPane: NSImage created from data. Size: \(nsImage.size)")
                        await MainActor.run {
                            self.previewURL = url
                            self.isLoading = false
                        }
                    } else {
                        print("PreviewPane: FAILED to create NSImage from data")
                        await MainActor.run {
                            self.errorMessage = "图片格式不支持"
                            self.isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "无法从手机拉取图片"
                        self.isLoading = false
                    }
                }
            } catch {
                print("PreviewPane: Task Failed: \(error)")
                await MainActor.run {
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
