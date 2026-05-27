import Foundation
import Network

class NetworkScanner: ObservableObject {
    @Published var discoveredIPs: [String] = []
    @Published var isScanning = false
    
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        discoveredIPs = []
        
        Task {
            let localSubnet = getLocalSubnet()
            
            guard let subnet = localSubnet else {
                await MainActor.run { isScanning = false }
                return
            }
            
            do {
                try await withThrowingTaskGroup(of: String?.self) { group in
                    for i in 1...254 {
                        let ip = "\(subnet).\(i)"
                        group.addTask {
                            return await self.checkADBPort(ip: ip)
                        }
                    }
                    
                    for try await result in group {
                        if let foundIP = result {
                            await MainActor.run {
                                if !self.discoveredIPs.contains(foundIP) {
                                    self.discoveredIPs.append(foundIP)
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Scanner: Scan error: \(error)")
            }
            
            await MainActor.run { isScanning = false }
        }
    }
    
    private func checkADBPort(ip: String) async -> String? {
        let host = NWEndpoint.Host(ip)
        let port = NWEndpoint.Port(rawValue: 5555)!
        let connection = NWConnection(host: host, port: port, using: .tcp)
        
        let lock = NSLock()
        var isResumed = false
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    lock.lock()
                    if !isResumed {
                        isResumed = true
                        lock.unlock()
                        connection.cancel()
                        continuation.resume(returning: ip)
                    } else {
                        lock.unlock()
                    }
                } else if case .failed = state {
                    lock.lock()
                    if !isResumed {
                        isResumed = true
                        lock.unlock()
                        continuation.resume(returning: nil)
                    } else {
                        lock.unlock()
                    }
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                lock.lock()
                if !isResumed {
                    isResumed = true
                    lock.unlock()
                    connection.cancel()
                    continuation.resume(returning: nil)
                } else {
                    lock.unlock()
                }
            }
        }
    }
    
    private func getLocalSubnet() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface!.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface!.ifa_addr, socklen_t(interface!.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        if let ip = address {
            let components = ip.components(separatedBy: ".")
            if components.count == 4 {
                return components.dropLast().joined(separator: ".")
            }
        }
        return nil
    }
}
