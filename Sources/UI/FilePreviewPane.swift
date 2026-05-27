import SwiftUI
import AVKit

/// A more stable VideoPlayer wrapper for macOS using AVPlayerView
struct NativeVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.allowsPictureInPicturePlayback = true
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct FilePreviewPane: View {
    let file: AndroidFile?
    let provider: FileProvider?
    
    @State private var previewURL: URL? = nil
    @State private var player: AVPlayer? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var videoAspectRatio: CGFloat? = nil

    var body: some View {
        VStack {
            if let file = file {
                ScrollView {
                    VStack(spacing: 20) {
                        // Media Section
                        Group {
                            if file.isImage {
                                imagePreviewSection(for: file)
                            } else if file.isVideo {
                                videoPreviewSection(for: file)
                            } else {
                                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(file.isDirectory ? .blue : .secondary)
                                    .padding(.vertical, 60)
                            }
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
                        }
                        .padding(.horizontal)
                        
                        Divider().padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow(label: "路径", value: file.path)
                            infoRow(label: "类型", value: file.isDirectory ? "文件夹" : (file.extensionName.uppercased() + " 文件"))
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            } else {
                emptyStateView
            }
        }
        .frame(minWidth: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadPreview(for: file)
        }
        .onDisappear {
            cancelLoading()
        }
        .onChange(of: file) { newFile in
            loadPreview(for: newFile)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("双击图片或视频以查看预览")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .cornerRadius(8)
                    .padding()
                    .shadow(radius: 4)
            } else if let error = errorMessage {
                errorView(error)
                    .frame(height: 200)
            }
        }
    }

    @ViewBuilder
    private func videoPreviewSection(for file: AndroidFile) -> some View {
        ZStack {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("正在拉取视频...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else if let player = player {
                NativeVideoPlayer(player: player)
                    .aspectRatio(videoAspectRatio ?? 16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .padding()
            } else if let error = errorMessage {
                errorView(error)
                    .frame(height: 200)
            }
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.body).textSelection(.enabled)
        }
    }
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        player?.pause()
        player = nil
        previewURL = nil
        videoAspectRatio = nil
    }
    
    private func loadPreview(for file: AndroidFile?) {
        cancelLoading()
        errorMessage = nil
        
        guard let file = file, (file.isImage || file.isVideo), let provider = provider else { return }
        
        isLoading = true
        loadingTask = Task {
            do {
                guard let url = try await provider.fetchPreviewData(for: file) else {
                    throw NSError(domain: "PreviewError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法从手机拉取文件"])
                }
                
                if Task.isCancelled { return }
                
                try await handleLoadedFile(url, isVideo: file.isVideo)
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    @MainActor
    private func handleLoadedFile(_ url: URL, isVideo: Bool) async throws {
        if isVideo {
            let asset = AVAsset(url: url)
            let isPlayable = try await asset.load(.isPlayable)
            if isPlayable {
                // Calculate aspect ratio
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    let displaySize = size.applying(transform)
                    let width = abs(displaySize.width)
                    let height = abs(displaySize.height)
                    if height > 0 {
                        self.videoAspectRatio = width / height
                    }
                }
                
                self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                self.previewURL = url
            } else {
                self.errorMessage = "视频文件不可播放或格式不支持"
            }
        } else {
            if let _ = NSImage(contentsOf: url) {
                self.previewURL = url
            } else {
                self.errorMessage = "图片解析失败"
            }
        }
        self.isLoading = false
    }
}
