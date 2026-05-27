import SwiftUI

struct NetworkManagerView: View {
    @StateObject private var scanner = NetworkScanner()
    @State private var manualIP: String = ""
    @State private var statusMessage: String? = nil
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("远程管理")
                    .font(.headline)
                Spacer()
                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Manual Connect
                    VStack(alignment: .leading, spacing: 12) {
                        Label("手动连接 IP", systemImage: "ipaddress.fill")
                            .font(.headline)
                        
                        HStack {
                            TextField("例如 192.168.1.10", text: $manualIP)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 300)
                            
                            Button(action: { connect(ip: manualIP) }) {
                                if isConnecting {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("连接")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(manualIP.isEmpty || isConnecting)
                        }
                        Text("提示：请确保手机已在开发者选项中开启“无线调试”")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    
                    // LAN Scan
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("局域网扫描", systemImage: "wifi.circle.fill")
                                .font(.headline)
                            Spacer()
                            Button(action: { scanner.scan() }) {
                                if scanner.isScanning {
                                    HStack {
                                        ProgressView().controlSize(.small)
                                        Text("扫描中...")
                                    }
                                } else {
                                    Label("开始扫描", systemImage: "magnifyingglass")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(scanner.isScanning)
                        }
                        
                        if scanner.discoveredIPs.isEmpty {
                            if scanner.isScanning {
                                Text("正在探测局域网中的安卓设备...")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                // Fallback for ContentUnavailableView (macOS 14+)
                                VStack(spacing: 12) {
                                    Image(systemName: "network.slash")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("未发现远程设备")
                                        .font(.headline)
                                    Text("点击扫描以搜索局域网内开放了 5555 端口的设备")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        } else {
                            LazyVStack(spacing: 1) {
                                ForEach(scanner.discoveredIPs, id: \.self) { ip in
                                    HStack {
                                        Image(systemName: "iphone.gen3")
                                            .foregroundColor(.green)
                                        Text(ip)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                        Button("连接") {
                                            connect(ip: ip)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .padding()
                                    .background(Color.secondary.opacity(0.03))
                                    Divider()
                                }
                            }
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func connect(ip: String) {
        isConnecting = true
        statusMessage = "正在连接 \(ip)..."
        
        Task {
            do {
                let target = ip.contains(":") ? ip : "\(ip):5555"
                let output = try await ADBDeviceManager.runADB(args: ["connect", target])
                await MainActor.run {
                    self.isConnecting = false
                    if output.contains("connected to") {
                        self.statusMessage = "连接成功"
                    } else {
                        self.statusMessage = "连接失败: \(output)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnecting = false
                    self.statusMessage = "连接异常: \(error.localizedDescription)"
                }
            }
        }
    }
}
