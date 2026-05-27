import Foundation
import Combine

class ADBDeviceManager: DeviceManager {
    @Published var connectedDevices: [AndroidDevice] = []
    private var timer: AnyCancellable?
    static let adbPath = "/opt/homebrew/bin/adb"

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
                let output = try await Self.runADB(args: ["devices", "-l"])
                let devices = parseDevicesOutput(output)
                DispatchQueue.main.async {
                    self.connectedDevices = devices
                }
            } catch {
                print("Failed to refresh devices: \(error)")
            }
        }
    }

    func connectTo(ip: String) async throws -> String {
        return try await Self.runADB(args: ["connect", ip])
    }

    func disconnect(ip: String) async throws -> String {
        return try await Self.runADB(args: ["disconnect", ip])
    }

    static func runADB(args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = args
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            do {
                try process.run()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    if let output = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ADBError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法解码 ADB 输出"]))
                    }
                } else {
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "未知错误"
                    continuation.resume(throwing: NSError(domain: "ADBError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseDevicesOutput(_ output: String) -> [AndroidDevice] {
        var devices: [AndroidDevice] = []
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("device") && !line.contains("List of devices") {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let serial = parts[0]
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
