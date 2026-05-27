import Foundation
import Combine

@MainActor
class DeviceMonitor: ObservableObject {
    let device: AndroidDevice
    
    @Published var hardwareInfo = HardwareInfo()
    @Published var batteryInfo = BatteryInfo()
    @Published var storageInfo = StorageInfo()
    @Published var cpuHistory: [PerformancePoint] = []
    @Published var ramHistory: [PerformancePoint] = []
    
    private var timer: AnyCancellable?
    private let historyLimit = 30
    
    // CPU calculation state
    private var lastTotalJiffies: Int64 = 0
    private var lastIdleJiffies: Int64 = 0
    
    init(device: AndroidDevice) {
        self.device = device
    }
    
    func start() {
        // 1. Fetch static info once
        fetchHardwareInfo()
        
        // 2. Start polling dynamic info
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.pollMetrics()
                }
            }
        
        Task {
            await self.pollMetrics()
        }
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
    
    private func fetchHardwareInfo() {
        Task {
            do {
                let brand = try await runADB(["shell", "getprop", "ro.product.brand"])
                let model = try await runADB(["shell", "getprop", "ro.product.model"])
                let androidV = try await runADB(["shell", "getprop", "ro.build.version.release"])
                let sdkV = try await runADB(["shell", "getprop", "ro.build.version.sdk"])
                let arch = try await runADB(["shell", "getprop", "ro.product.cpu.abi"])
                let res = try await runADB(["shell", "wm", "size"])
                
                let resolution = res.replacingOccurrences(of: "Physical size: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                self.hardwareInfo = HardwareInfo(
                    brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                    androidVersion: androidV.trimmingCharacters(in: .whitespacesAndNewlines),
                    sdkVersion: sdkV.trimmingCharacters(in: .whitespacesAndNewlines),
                    resolution: resolution,
                    cpuArch: arch.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } catch {
                print("Monitor: Failed to fetch hardware info: \(error)")
            }
        }
    }
    
    private func pollMetrics() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.pollCPU() }
            group.addTask { await self.pollRAM() }
            group.addTask { await self.pollStorage() }
            group.addTask { await self.pollBattery() }
        }
    }
    
    private func pollCPU() async {
        do {
            let stat = try await runADB(["shell", "cat", "/proc/stat | head -n 1"])
            let parts = stat.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Format: cpu  user nice system idle iowait irq softirq ...
            if parts.count >= 5 {
                let user = Int64(parts[1]) ?? 0
                let nice = Int64(parts[2]) ?? 0
                let system = Int64(parts[3]) ?? 0
                let idle = Int64(parts[4]) ?? 0
                let iowait = Int64(parts[5]) ?? 0
                
                let currentIdle = idle + iowait
                let currentTotal = user + nice + system + currentIdle + (Int64(parts[6]) ?? 0) + (Int64(parts[7]) ?? 0)
                
                if lastTotalJiffies > 0 {
                    let totalDiff = currentTotal - lastTotalJiffies
                    let idleDiff = currentIdle - lastIdleJiffies
                    if totalDiff > 0 {
                        let usage = Double(totalDiff - idleDiff) / Double(totalDiff) * 100.0
                        updateHistory(&cpuHistory, value: usage)
                    }
                }
                
                lastTotalJiffies = currentTotal
                lastIdleJiffies = currentIdle
            }
        } catch {
            print("Monitor: CPU poll error: \(error)")
        }
    }
    
    private func pollRAM() async {
        do {
            let meminfo = try await runADB(["shell", "cat", "/proc/meminfo | grep -E 'MemTotal|MemAvailable'"])
            let lines = meminfo.components(separatedBy: .newlines)
            var total: Double = 0
            var available: Double = 0
            
            for line in lines {
                let parts = line.components(separatedBy: ":")
                if parts.count == 2 {
                    let val = Double(parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " kB", with: "")) ?? 0
                    if line.contains("MemTotal") { total = val }
                    if line.contains("MemAvailable") { available = val }
                }
            }
            
            if total > 0 {
                let usagePercent = (total - available) / total * 100.0
                updateHistory(&ramHistory, value: usagePercent)
            }
        } catch {
            print("Monitor: RAM poll error: \(error)")
        }
    }
    
    private func pollStorage() async {
        do {
            let df = try await runADB(["shell", "df", "/data"])
            let lines = df.components(separatedBy: .newlines)
            if lines.count >= 2 {
                let parts = lines[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 4 {
                    // df output usually: Filesystem Size Used Free BlkSize
                    // But toybox df is: Filesystem 1K-blocks Used Available Use% Mounted on
                    let totalK = Int64(parts[1]) ?? 0
                    let usedK = Int64(parts[2]) ?? 0
                    let availK = Int64(parts[3]) ?? 0
                    
                    self.storageInfo = StorageInfo(
                        total: totalK * 1024,
                        used: usedK * 1024,
                        available: availK * 1024
                    )
                }
            }
        } catch {
            print("Monitor: Storage poll error: \(error)")
        }
    }
    
    private func pollBattery() async {
        do {
            let battery = try await runADB(["shell", "dumpsys", "battery"])
            let lines = battery.components(separatedBy: .newlines)
            var info = BatteryInfo()
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.components(separatedBy: ":")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let val = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    switch key {
                    case "level": info.level = Int(val) ?? 0
                    case "status": 
                        let s = Int(val) ?? 1
                        info.status = (s == 2) ? "正在充电" : (s == 5) ? "已充满" : "未充电"
                    case "temperature": info.temperature = (Double(val) ?? 0) / 10.0
                    case "health": info.health = "良好" // Simplified
                    default: break
                    }
                }
            }
            self.batteryInfo = info
        } catch {
            print("Monitor: Battery poll error: \(error)")
        }
    }
    
    private func updateHistory(_ history: inout [PerformancePoint], value: Double) {
        let point = PerformancePoint(timestamp: Date(), value: value)
        history.append(point)
        if history.count > historyLimit {
            history.removeFirst()
        }
    }
    
    private func runADB(_ args: [String]) async throws -> String {
        return try await ADBDeviceManager.runADB(args: ["-s", device.serial] + args)
    }
}
