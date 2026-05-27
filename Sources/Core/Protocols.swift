import Foundation

/// Defines the operations supported for interacting with an Android device's file system.
protocol FileProvider {
    var device: AndroidDevice { get }

    func listFiles(at path: String) async throws -> [AndroidFile]
    func copyToLocal(remotePath: String, localPath: String, progress: @escaping (Double) -> Void) async throws
    func copyToDevice(localPath: String, remotePath: String, progress: @escaping (Double) -> Void) async throws
    func delete(at path: String) async throws
    func createDirectory(at path: String) async throws
}

/// Manages device connection state and discovery.
protocol DeviceManager: ObservableObject {
    var connectedDevices: [AndroidDevice] { get }
    func startDiscovery()
    func stopDiscovery()
}

struct FileTransferProgress {
    let fileName: String
    let fractionCompleted: Double
    let totalSize: Int64
    let bytesCompleted: Int64
}
