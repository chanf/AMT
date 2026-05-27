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
}
