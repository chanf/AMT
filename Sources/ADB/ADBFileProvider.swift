import Foundation

class ADBFileProvider: FileProvider {
    let device: AndroidDevice
    private let adbPath: String
    private let aaptPath: String

    init(device: AndroidDevice) {
        self.device = device
        // Try common locations or use 'which adb' logic
        self.adbPath = "/opt/homebrew/bin/adb" 
        self.aaptPath = "/Users/feng/opt/android-sdk/build-tools/35.0.1/aapt"
    }

    func listFiles(at path: String) async throws -> [AndroidFile] {
        // Use a trailing slash for directories to ensure symlinks are followed by ls
        let targetPath = (path.hasSuffix("/") || path.isEmpty) ? path : "\(path)/"
        print("ADB: Listing files at \(path) (using \(targetPath))")
        
        let output = try await runADB(args: ["-s", device.serial, "shell", "ls", "-la", targetPath])
        return parseLSOutput(output, parentPath: path)
    }

    func copyToLocal(remotePath: String, localPath: String, progress: @escaping (Double) -> Void) async throws {
        _ = try await runADB(args: ["-s", device.serial, "pull", remotePath, localPath])
        progress(1.0)
    }

    func copyToDevice(localPath: String, remotePath: String, progress: @escaping (Double) -> Void) async throws {
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
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
            return nil
        } catch {
            print("Preview: ADB Pull Failed: \(error)")
            throw error
        }
    }

    func installAPK(at path: String) async throws {
        let tmpPath = "/data/local/tmp/temp_install.apk"
        _ = try await runADB(args: ["-s", device.serial, "shell", "cp", path, tmpPath])
        do {
            _ = try await runADB(args: ["-s", device.serial, "shell", "pm", "install", "-r", tmpPath])
            _ = try await runADB(args: ["-s", device.serial, "shell", "rm", tmpPath])
        } catch {
            _ = try await runADB(args: ["-s", device.serial, "shell", "rm", tmpPath])
            throw error
        }
    }

    func listApps() async throws -> [AndroidApp] {
        let output = try await runADB(args: ["-s", device.serial, "shell", "pm", "list", "packages", "-3", "-f"])
        let lines = output.components(separatedBy: .newlines)
        var apps: [AndroidApp] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || !trimmed.hasPrefix("package:") { continue }
            let content = String(trimmed.dropFirst("package:".count)).trimmingCharacters(in: .whitespaces)
            if let lastEqualIndex = content.lastIndex(of: "=") {
                let path = String(content[..<lastEqualIndex])
                let pkg = String(content[content.index(after: lastEqualIndex)...]).trimmingCharacters(in: .whitespaces)
                if !pkg.isEmpty {
                    apps.append(AndroidApp(packageName: pkg, name: AppCacheManager.shared.getName(for: pkg), remotePath: path))
                }
            }
        }
        return apps
    }

    func uninstallApp(packageName: String) async throws {
        _ = try await runADB(args: ["-s", device.serial, "shell", "pm", "uninstall", packageName])
    }

    func enableWirelessADB() async throws -> String {
        // 1. Switch to TCPIP mode
        _ = try await runADB(args: ["-s", device.serial, "tcpip", "5555"])
        
        // 2. Wait a bit for the device to restart ADB daemon
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 3. Get IP Address
        let ip = try await getIPAddress()
        
        // 4. Connect
        return try await ADBDeviceManager.runADB(args: ["connect", "\(ip):5555"])
    }

    func disableWirelessADB() async throws {
        // Switch adb daemon back to USB mode. 
        // This will immediately drop the current wireless connection.
        _ = try await runADB(args: ["-s", device.serial, "usb"])
    }

    private func getIPAddress() async throws -> String {
        // Try multiple methods to get IP
        let output = try await runADB(args: ["-s", device.serial, "shell", "ip", "addr", "show", "wlan0"])
        // Look for: inet 192.168.1.10/24 ...
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("inet ") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2 {
                    let ipWithSubnet = parts[1]
                    return ipWithSubnet.components(separatedBy: "/")[0]
                }
            }
        }
        throw NSError(domain: "ADBError", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法获取手机 IP 地址，请检查 Wi-Fi 是否连接"])
    }

    func fetchAppDetails(app: AndroidApp) async throws -> AndroidApp {
        var updatedApp = app
        let packageName = app.packageName

        var apkPath = app.remotePath
        if apkPath == nil {
            let pathOutput = try await runADB(args: ["-s", device.serial, "shell", "pm", "path", packageName])
            apkPath = pathOutput.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let finalRemotePath = apkPath else { return updatedApp }

        let localTempAPK = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(packageName).apk")
        _ = try await runADB(args: ["-s", device.serial, "pull", finalRemotePath, localTempAPK.path])
        defer { try? FileManager.default.removeItem(at: localTempAPK) }

        let aaptOutput = try await runLocalCommand(executable: aaptPath, args: ["dump", "badging", localTempAPK.path])
        let lines = aaptOutput.components(separatedBy: .newlines)
        var internalIconPath: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("application-label:") {
                let label = trimmed.components(separatedBy: ":").last?.replacingOccurrences(of: "'", with: "").trimmingCharacters(in: .whitespaces)
                if let label = label, !label.isEmpty {
                    updatedApp.name = label
                    AppCacheManager.shared.saveName(label, for: packageName)
                }
            }
            if trimmed.hasPrefix("package:") {
                if let vName = extractValue(from: trimmed, for: "versionName") { updatedApp.versionName = vName }
                if let vCode = extractValue(from: trimmed, for: "versionCode") { updatedApp.versionCode = vCode }
            }
            if internalIconPath == nil && (trimmed.contains("application-icon-") || trimmed.hasPrefix("icon=")) {
                internalIconPath = trimmed.components(separatedBy: ":").last?.replacingOccurrences(of: "'", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        if let iconPath = internalIconPath {
            let localIconURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(packageName)_icon.png")
            do {
                _ = try await runLocalCommand(executable: "/usr/bin/unzip", args: ["-p", localTempAPK.path, iconPath], outputPath: localIconURL.path)
                updatedApp.iconURL = localIconURL
            } catch {
                print("ADB: Failed to extract icon: \(error)")
            }
        }
        return updatedApp
    }

    // MARK: - Helper Methods

    private func extractValue(from line: String, for key: String) -> String? {
        let pattern = "\(key)='([^']*)'"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            if let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }
        return nil
    }

    private func runLocalCommand(executable: String, args: [String], outputPath: String? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            let outputPipe = Pipe()
            if let outPath = outputPath {
                try? FileManager.default.createFile(atPath: outPath, contents: nil)
                if let fileHandle = FileHandle(forWritingAtPath: outPath) { process.standardOutput = fileHandle }
            } else {
                process.standardOutput = outputPipe
            }
            do {
                try process.run()
                var output = ""
                if outputPath == nil {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    output = String(data: data, encoding: .utf8) ?? ""
                }
                process.waitUntilExit()
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

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
                        continuation.resume(throwing: NSError(domain: "ADBError", code: 1))
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
            if parts.count >= 8 {
                let permissions = parts[0]
                let isDirectory = permissions.hasPrefix("d")
                let isSymlink = permissions.hasPrefix("l")
                let nameParts = Array(parts.suffix(from: 7))
                var name = nameParts.joined(separator: " ")
                if isSymlink, let arrowIndex = nameParts.firstIndex(of: "->") {
                    name = nameParts[0..<arrowIndex].joined(separator: " ")
                }
                if name == "." || name == ".." { continue }
                let sizeStr = parts[4]
                let size = Int64(sizeStr) ?? 0
                let filePath = parentPath.hasSuffix("/") ? "\(parentPath)\(name)" : "\(parentPath)/\(name)"
                files.append(AndroidFile(id: UUID().uuidString, name: name, path: filePath, isDirectory: isDirectory || isSymlink, size: size, modificationDate: nil))
            }
        }
        return files
    }
}
