import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    let device: AndroidDevice
    @Binding var externalTargetPath: String?
    @Binding var selectedFile: AndroidFile?
    
    @State private var files: [AndroidFile] = []
    @State private var currentPath: String = "/sdcard"
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var isDropTargeted = false

    @StateObject var transferManager = TransferManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Device Info Header
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
                    Button(action: launchScrcpy) {
                        Label("屏幕镜像", systemImage: "display")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()

            // Toolbar
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
                
                if !transferManager.activeTransfers.isEmpty {
                    Text("Transferring...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(files) { file in
                    FileRow(file: file, progress: transferManager.activeTransfers[file.path])
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if file.isDirectory {
                                selectedFile = nil
                                navigate(to: file.path)
                            } else if file.isImage {
                                selectedFile = file
                            } else {
                                selectedFile = nil
                            }
                        }
                        .contextMenu {
                            if !file.isDirectory {
                                Button {
                                    copyToMac(file: file)
                                } label: {
                                    Label("Copy to Mac", systemImage: "square.and.arrow.down")
                                }
                            }
                            Button(role: .destructive) {
                                // delete implementation
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .background(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
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

    func copyToMac(file: AndroidFile) {
        transferManager.copyToLocal(file: file, provider: getProvider())
    }

    func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    urls.append(url)
                }
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
            // Ensure common Homebrew paths are included
            let command = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin; scrcpy -s \(serial)"
            process.arguments = ["-c", command]
            do {
                try process.run()
            } catch {
                print("Failed to launch scrcpy: \(error)")
            }
        }
    }

    func navigate(to path: String) {
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
