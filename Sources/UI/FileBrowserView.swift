import SwiftUI
import UniformTypeIdentifiers

struct FileRow: View {
    let file: AndroidFile
    var progress: Double?

    var body: some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(file.isDirectory ? .blue : .secondary)
            VStack(alignment: .leading) {
                Text(file.name)
                if !file.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let p = progress {
                ProgressView(value: p)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct FileBrowserView: View {
    let device: AndroidDevice
    @Binding var externalTargetPath: String?
    @Binding var selectedFileIDs: Set<String>
    
    @State private var files: [AndroidFile] = []
    @State private var currentPath: String = "/sdcard"
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var isDropTargeted = false
    @State private var message: String? = nil
    @State private var previewFile: AndroidFile? = nil
    @State private var lastSelectedFileID: String? = nil

    @StateObject var transferManager = TransferManager.shared

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Device Info Header
                headerView
                
                Divider()

                // Toolbar
                toolbarView

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    fileListView
                }
            }
            .contentShape(Rectangle())
            .overlay(dropOverlay)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }

            // Integrated Preview Pane
            if let preview = previewFile {
                Divider()
                FilePreviewPane(file: preview, provider: getProvider())
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.spring(), value: preview.id)
            }
        }
        .navigationTitle(device.model)
        .onAppear(perform: refresh)
        .searchable(text: $searchText)
        .onChange(of: externalTargetPath) { newPath in
            if let path = newPath {
                navigate(to: path)
                externalTargetPath = nil
            }
        }
        .onChange(of: selectedFileIDs) { ids in
            if let current = previewFile, !ids.contains(current.id) {
                previewFile = nil
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.model)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(device.connectionType.rawValue.uppercased(), systemImage: "cable.connector")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Label("S/N: \(device.serial)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if device.connectionType == .adb {
                HStack(spacing: 12) {
                    // Only show Wireless button if it's currently a USB connection (no IP port in serial)
                    if !device.serial.contains(":") {
                        Button(action: enableWireless) {
                            Label("无线管理", systemImage: "wifi")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: launchScrcpy) {
                        Label("屏幕镜像", systemImage: "display")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var toolbarView: some View {
        HStack {
            Button(action: goUp) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPath == "/")

            Text(currentPath)
                .font(.callout)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            Spacer()
            
            if let msg = message {
                Text(msg).font(.caption).foregroundColor(.blue)
            }

            if !transferManager.activeTransfers.isEmpty {
                Text("Transferring...").font(.caption).foregroundColor(.blue)
            }

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
    }

    private var fileListView: some View {
        List {
            ForEach(files) { file in
                Button(action: {
                    handleSelection(for: file)
                }) {
                    FileRow(file: file, progress: transferManager.activeTransfers[file.path])
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedFileIDs.contains(file.id) ? 
                    Color.blue.opacity(0.15) : 
                    Color.clear
                )
                .listRowInsets(EdgeInsets())
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    handleDoubleTap(file: file)
                })
                .contextMenu {
                    contextMenuContent(for: file)
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func contextMenuContent(for file: AndroidFile) -> some View {
        let targets = (selectedFileIDs.contains(file.id) && selectedFileIDs.count > 1) 
            ? files.filter { selectedFileIDs.contains($0.id) } 
            : [file]

        let allAPKs = !targets.isEmpty && targets.allSatisfy { $0.isAPK }
        if allAPKs {
            Button { installAPKs(files: targets) } label: {
                Label(targets.count > 1 ? "安装 \(targets.count) 个 APK" : "安装 APK", systemImage: "arrow.down.app")
            }
        }
        
        Button { copyToMac(files: targets) } label: {
            Label(targets.count > 1 ? "下载 \(targets.count) 个项目" : "下载到 Mac", systemImage: "square.and.arrow.down")
        }
        
        Button(role: .destructive) { deleteFiles(files: targets) } label: {
            Label(targets.count > 1 ? "删除 \(targets.count) 个项目" : "删除", systemImage: "trash")
        }
    }

    private var dropOverlay: some View {
        Group {
            if isDropTargeted {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    VStack {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 50))
                        Text("拖拽至此上传到当前目录").font(.headline)
                    }
                    .foregroundColor(.accentColor)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Actions

    private func handleSelection(for file: AndroidFile) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let lastID = lastSelectedFileID {
            // Range selection
            if let startIndex = files.firstIndex(where: { $0.id == lastID }),
               let endIndex = files.firstIndex(where: { $0.id == file.id }) {
                let start = min(startIndex, endIndex)
                let end = max(startIndex, endIndex)
                selectedFileIDs = Set(files[start...end].map { $0.id })
            }
        } else if flags.contains(.command) {
            // Toggle selection
            if selectedFileIDs.contains(file.id) {
                selectedFileIDs.remove(file.id)
            } else {
                selectedFileIDs.insert(file.id)
            }
            lastSelectedFileID = file.id
        } else {
            // Single selection
            selectedFileIDs = [file.id]
            lastSelectedFileID = file.id
        }
    }

    private func handleDoubleTap(file: AndroidFile) {
        if file.isDirectory {
            selectedFileIDs.removeAll()
            previewFile = nil
            navigate(to: file.path)
        } else if file.isAPK {
            installAPKs(files: [file])
        } else if file.isImage || file.isVideo || file.isText || file.isAudio {
            previewFile = file
        }
    }

    private func getProvider() -> FileProvider {
        if device.connectionType == .adb {
            return ADBFileProvider(device: device)
        } else {
            return MTPFileProvider(device: device)
        }
    }

    func refresh() {
        isLoading = true
        let provider = getProvider()
        Task {
            do {
                self.files = try await provider.listFiles(at: currentPath)
                self.isLoading = false
            } catch {
                print("Error: \(error)")
                self.isLoading = false
            }
        }
    }

    func copyToMac(files: [AndroidFile]) {
        let provider = getProvider()
        for file in files {
            transferManager.copyToLocal(file: file, provider: provider)
        }
    }

    func enableWireless() {
        message = "正在切换无线模式..."
        let provider = getProvider() as? ADBFileProvider
        Task {
            do {
                let output = try await provider?.enableWirelessADB()
                await MainActor.run {
                    self.message = "无线模式已开启: \(output ?? "")"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.message = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.message = "开启失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func installAPKs(files: [AndroidFile]) {
        let provider = getProvider()
        Task {
            for file in files {
                await MainActor.run { self.message = "正在安装 \(file.name)..." }
                do {
                    try await provider.installAPK(at: file.path)
                    await MainActor.run { self.message = "安装成功: \(file.name)" }
                } catch {
                    await MainActor.run { self.message = "安装失败: \(error.localizedDescription)" }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.message = nil
                }
            }
        }
    }

    func deleteFiles(files: [AndroidFile]) {
        let provider = getProvider()
        Task {
            for file in files {
                do {
                    try await provider.delete(at: file.path)
                } catch {
                    print("Delete failed for \(file.name): \(error)")
                }
            }
            await MainActor.run {
                self.selectedFileIDs.removeAll()
                self.refresh()
            }
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                transferManager.uploadToDevice(localURLs: urls, remotePath: currentPath, provider: getProvider()) {
                    self.refresh()
                }
            }
        }
    }

    func launchScrcpy() {
        let serial = device.serial
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            let command = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin; scrcpy -s \(serial)"
            process.arguments = ["-c", command]
            try? process.run()
        }
    }

    func navigate(to path: String) {
        previewFile = nil
        lastSelectedFileID = nil
        currentPath = path
        refresh()
    }

    func goUp() {
        let components = currentPath.split(separator: "/")
        if components.count > 0 {
            currentPath = "/" + components.dropLast().joined(separator: "/")
            if currentPath == "" { currentPath = "/" }
            refresh()
        }
    }
}
