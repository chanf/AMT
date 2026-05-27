import Foundation

class MockDeviceManager: DeviceManager {
    @Published var connectedDevices: [AndroidDevice] = []

    func startDiscovery() {
        // Simulate finding devices
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectedDevices = [
                AndroidDevice(id: "1", model: "Pixel 7 Pro", serial: "ADB12345", connectionType: .adb),
                AndroidDevice(id: "2", model: "Samsung S23", serial: "MTP67890", connectionType: .mtp)
            ]
        }
    }

    func stopDiscovery() {
        connectedDevices = []
    }
}

class MockFileProvider: FileProvider {
    let device: AndroidDevice

    init(device: AndroidDevice) {
        self.device = device
    }

    func listFiles(at path: String) async throws -> [AndroidFile] {
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        return [
            AndroidFile(id: "1", name: "DCIM", path: "\(path)/DCIM", isDirectory: true, size: 0, modificationDate: Date()),
            AndroidFile(id: "2", name: "Documents", path: "\(path)/Documents", isDirectory: true, size: 0, modificationDate: Date()),
            AndroidFile(id: "3", name: "photo.jpg", path: "\(path)/photo.jpg", isDirectory: false, size: 1024 * 1024 * 5, modificationDate: Date()),
            AndroidFile(id: "4", name: "notes.txt", path: "\(path)/notes.txt", isDirectory: false, size: 512, modificationDate: Date())
        ]
    }

    func copyToLocal(remotePath: String, localPath: String, progress: @escaping (Double) -> Void) async throws {
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            progress(Double(i) / 10.0)
        }
    }

    func copyToDevice(localPath: String, remotePath: String, progress: @escaping (Double) -> Void) async throws {
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            progress(Double(i) / 10.0)
        }
    }

    func delete(at path: String) async throws {}
    func createDirectory(at path: String) async throws {}
    func fetchPreviewData(for file: AndroidFile) async throws -> URL? {
        return nil
    }

    func installAPK(at path: String) async throws {}
    func listApps() async throws -> [AndroidApp] {
        return [
            AndroidApp(packageName: "com.example.app1"),
            AndroidApp(packageName: "com.example.app2"),
            AndroidApp(packageName: "com.android.chrome")
        ]
    }
    func uninstallApp(packageName: String) async throws {}
    func fetchAppName(packageName: String) async throws -> String? { return "Mock App Name" }
}
