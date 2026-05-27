import Foundation
import Combine

class ADBDeviceManager: DeviceManager {
    @Published var connectedDevices: [AndroidDevice] = []
    private var timer: AnyCancellable?
    private let adbPath = "/opt/homebrew/bin/adb"

    func startDiscovery() {
        // Poll for devices every 2 seconds
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshDevices()
            }
        refreshDevices()
    }

    func stopDiscovery() {
        timer?.cancel()
        timer = nil
    }

    private func refreshDevices() {
        Task {
            do {
                let output = try await runADB(args: ["devices", "-l"])
                let devices = parseDevicesOutput(output)
                DispatchQueue.main.async {
                    self.connectedDevices = devices
                }
            } catch {
                print("Failed to refresh devices: \(error)")
            }
        }
    }

    private func runADB(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: NSError(domain: "ADBError", code: 1))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseDevicesOutput(_ output: String) -> [AndroidDevice] {
        var devices: [AndroidDevice] = []
        let lines = output.components(separatedBy: .newlines)
        // Header: List of devices attached
        for line in lines {
            if line.contains("device") && !line.contains("List of devices") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let serial = parts[0]
                    // Look for model:XXX
                    var model = "Android Device"
                    if let modelPart = parts.first(where: { $0.hasPrefix("model:") }) {
                        model = modelPart.replacingOccurrences(of: "model:", with: "")
                    }
                    devices.append(AndroidDevice(id: serial, model: model, serial: serial, connectionType: .adb))
                }
            }
        }
        return devices
    }
}
