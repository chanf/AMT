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
        // Use a trailing slash for directories to ensure symlinks are followed by ls
        let targetPath = (path.hasSuffix("/") || path.isEmpty) ? path : "\(path)/"
        print("ADB: Listing files at \(path) (using \(targetPath))")
        
        let output = try await runADB(args: ["-s", device.serial, "shell", "ls", "-la", targetPath])
        // print("ADB: Raw output length: \(output.count)")
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
        
        print("Preview: Pulling \(file.path) to \(localURL.path)")
        do {
            let output = try await runADB(args: ["-s", device.serial, "pull", file.path, localURL.path])
            print("Preview: ADB Output: \(output)")
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                print("Preview: File exists at \(localURL.path)")
                return localURL
            } else {
                print("Preview: File DOES NOT exist at \(localURL.path)")
                return nil
            }
        } catch {
            print("Preview: ADB Pull Failed: \(error)")
            throw error
        }
    }

    func installAPK(at path: String) async throws {
        // Run: adb -s <serial> shell pm install -r <path>
        _ = try await runADB(args: ["-s", device.serial, "shell", "pm", "install", "-r", path])
    }

    func listApps() async throws -> [AndroidApp] {
        // Run: adb -s <serial> shell pm list packages -3 (third party only)
        let output = try await runADB(args: ["-s", device.serial, "shell", "pm", "list", "packages", "-3"])
        let lines = output.components(separatedBy: .newlines)
        var apps: [AndroidApp] = []
        for line in lines {
            if line.hasPrefix("package:") {
                let packageName = line.replacingOccurrences(of: "package:", with: "")
                if !packageName.isEmpty {
                    apps.append(AndroidApp(packageName: packageName))
                }
            }
        }
        return apps
    }

    func uninstallApp(packageName: String) async throws {
        // Run: adb -s <serial> shell pm uninstall <packageName>
        _ = try await runADB(args: ["-s", device.serial, "shell", "pm", "uninstall", packageName])
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
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("total ") { continue }
            
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            // Expected format: [perms] [links] [owner] [group] [size] [date] [time] [name...]
            if parts.count >= 8 {
                let permissions = parts[0]
                let isDirectory = permissions.hasPrefix("d")
                let isSymlink = permissions.hasPrefix("l")
                
                // Filename starts at index 7.
                // If it's a symlink, the part will be "name -> target"
                var nameParts = Array(parts.suffix(from: 7))
                var name = nameParts.joined(separator: " ")
                
                if isSymlink {
                    // Extract name before " -> "
                    if let arrowIndex = nameParts.firstIndex(of: "->") {
                        name = nameParts[0..<arrowIndex].joined(separator: " ")
                    }
                }
                
                if name == "." || name == ".." { continue }

                let sizeStr = parts[4]
                let size = Int64(sizeStr) ?? 0
                
                let filePath = parentPath.hasSuffix("/") ? "\(parentPath)\(name)" : "\(parentPath)/\(name)"
                
                files.append(AndroidFile(
                    id: UUID().uuidString,
                    name: name,
                    path: filePath,
                    isDirectory: isDirectory || isSymlink, // Treat symlinks as directories for navigation if they point to one (simplified)
                    size: size,
                    modificationDate: nil
                ))
            }
        }
        return files
    }
}
