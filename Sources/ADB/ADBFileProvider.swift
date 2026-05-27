import Foundation

class ADBFileProvider: FileProvider {
    let device: AndroidDevice
    private let adbPath: String

    init(device: AndroidDevice) {
        self.device = device
        // Try common locations or use 'which adb' logic
        self.adbPath = "/opt/homebrew/bin/adb" 
    }

    func listFiles(at path: String) async throws -> [AndroidFile] {
        // Run: adb -s <serial> shell ls -la <path>
        let output = try await runADB(args: ["-s", device.serial, "shell", "ls", "-la", path])
        return parseLSOutput(output, parentPath: path)
    }

    func copyToLocal(remotePath: String, localPath: String, progress: @escaping (Double) -> Void) async throws {
        // Run: adb -s <serial> pull <remote> <local>
        // Note: adb pull doesn't give easy progress via stdout unless we parse it.
        // For simplicity, we run it and assume completion.
        _ = try await runADB(args: ["-s", device.serial, "pull", remotePath, localPath])
        progress(1.0)
    }

    func copyToDevice(localPath: String, remotePath: String, progress: @escaping (Double) -> Void) async throws {
        // Run: adb -s <serial> push <local> <remote>
        _ = try await runADB(args: ["-s", device.serial, "push", localPath, remotePath])
        progress(1.0)
    }

    func delete(at path: String) async throws {
        _ = try await runADB(args: ["-s", device.serial, "shell", "rm", "-rf", path])
    }

    func createDirectory(at path: String) async throws {
        _ = try await runADB(args: ["-s", device.serial, "shell", "mkdir", "-p", path])
    }

    func fetchPreviewData(for file: AndroidFile) async throws -> URL? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let localURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(file.extensionName)
        
        _ = try await runADB(args: ["-s", device.serial, "pull", file.path, localURL.path])
        return localURL
    }

    // MARK: - Helper Methods

    private func runADB(args: [String]) async throws -> String {
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
                        continuation.resume(throwing: NSError(domain: "ADBError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode output"]))
                    }
                } else {
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: NSError(domain: "ADBError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseLSOutput(_ output: String, parentPath: String) -> [AndroidFile] {
        var files: [AndroidFile] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            // Typical line: drwxrwx--x 15 root sdcard_rw 4096 2023-01-01 12:00 Alarms
            if parts.count >= 8 {
                let permissions = parts[0]
                let isDirectory = permissions.hasPrefix("d")
                let name = parts.suffix(from: 7).joined(separator: " ")
                
                if name == "." || name == ".." { continue }

                let sizeStr = parts[4]
                let size = Int64(sizeStr) ?? 0
                
                let filePath = parentPath.hasSuffix("/") ? "\(parentPath)\(name)" : "\(parentPath)/\(name)"
                
                files.append(AndroidFile(
                    id: UUID().uuidString,
                    name: name,
                    path: filePath,
                    isDirectory: isDirectory,
                    size: size,
                    modificationDate: nil // Parsing date is more complex, skipping for now
                ))
            }
        }
        return files
    }
}
