import Foundation

class TransferManager: ObservableObject {
    @Published var activeTransfers: [String: Double] = [:] // remotePath: progress

    static let shared = TransferManager()
    private init() {}

    func copyToLocal(file: AndroidFile, provider: FileProvider) {
        let destination = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").appendingPathComponent(file.name).path
        
        Task {
            do {
                try await provider.copyToLocal(remotePath: file.path, localPath: destination) { progress in
                    DispatchQueue.main.async {
                        self.activeTransfers[file.path] = progress
                    }
                }
                DispatchQueue.main.async {
                    self.activeTransfers.removeValue(forKey: file.path)
                }
            } catch {
                print("Transfer failed: \(error)")
                DispatchQueue.main.async {
                    self.activeTransfers.removeValue(forKey: file.path)
                }
            }
        }
    }

    func uploadToDevice(localURLs: [URL], remotePath: String, provider: FileProvider, onComplete: @escaping () -> Void) {
        Task {
            for url in localURLs {
                let fileName = url.lastPathComponent
                let destination = remotePath.hasSuffix("/") ? "\(remotePath)\(fileName)" : "\(remotePath)/\(fileName)"
                
                print("Uploading \(url.path) to \(destination)")
                
                do {
                    try await provider.copyToDevice(localPath: url.path, remotePath: destination) { progress in
                        DispatchQueue.main.async {
                            self.activeTransfers[url.path] = progress
                        }
                    }
                    DispatchQueue.main.async {
                        self.activeTransfers.removeValue(forKey: url.path)
                    }
                } catch {
                    print("Upload failed: \(error)")
                    DispatchQueue.main.async {
                        self.activeTransfers.removeValue(forKey: url.path)
                    }
                }
            }
            DispatchQueue.main.async {
                onComplete()
            }
        }
    }
}
