import SwiftUI
import Charts

struct DevicePerformanceView: View {
    let device: AndroidDevice
    @StateObject private var monitor: DeviceMonitor
    
    init(device: AndroidDevice) {
        self.device = device
        _monitor = StateObject(wrappedValue: DeviceMonitor(device: device))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // 1. Hardware Info Header
                hardwareInfoSection
                
                Divider()
                
                // 2. Real-time Monitoring (CPU & RAM)
                HStack(spacing: 20) {
                    chartCard(title: "CPU 使用率", points: monitor.cpuHistory, color: .green, unit: "%", range: 0...100)
                    chartCard(title: "内存使用率", points: monitor.ramHistory, color: .blue, unit: "%", range: 0...100)
                }
                .frame(height: 250)
                
                // 3. Thermal Monitoring
                thermalSection
                
                Divider()
                
                // 4. Storage & Battery
                HStack(alignment: .top, spacing: 20) {
                    storageCard
                    batteryCard
                }
            }
            .padding()
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .navigationTitle("\(device.model) - 性能面板")
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Subviews
    
    private var hardwareInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("硬件与系统信息")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                infoItem(title: "品牌型号", value: "\(monitor.hardwareInfo.brand) \(monitor.hardwareInfo.model)", icon: "iphone")
                infoItem(title: "Android 版本", value: "Android \(monitor.hardwareInfo.androidVersion) (API \(monitor.hardwareInfo.sdkVersion))", icon: "gearshape")
                infoItem(title: "屏幕分辨率", value: monitor.hardwareInfo.resolution, icon: "iphone.gen2")
                infoItem(title: "CPU 架构", value: monitor.hardwareInfo.cpuArch, icon: "cpu")
                infoItem(title: "连接方式", value: device.connectionType.rawValue.uppercased(), icon: "cable.connector")
                infoItem(title: "序列号", value: device.serial, icon: "number")
            }
        }
    }
    
    private func infoItem(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .bold()
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    private var thermalSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("温度监控")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if monitor.thermalInfo.cpuTemp > 0 {
                    Text("当前系统温: \(String(format: "%.1f", monitor.thermalInfo.cpuTemp))°C")
                        .font(.subheadline.bold())
                        .foregroundColor(tempColor(monitor.thermalInfo.cpuTemp))
                }
            }
            
            chartCard(title: "实时温度轨迹", points: monitor.thermalHistory, color: .orange, unit: "°C", range: 20...100)
                .frame(height: 200)
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp < 45 { return .green }
        if temp < 60 { return .orange }
        return .red
    }
    
    private func chartCard(title: String, points: [PerformancePoint], color: Color, unit: String, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let last = points.last {
                    Text("\(String(format: "%.1f", last.value))\(unit)")
                        .font(.title3.monospacedDigit())
                        .bold()
                        .foregroundColor(color)
                }
            }
            
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.value)
                    )
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.5), color.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                    
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: range)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var storageCard: some View {
        VStack(alignment: .leading) {
            Text("内部存储空间").font(.headline)
            
            HStack(spacing: 30) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: monitor.storageInfo.usedPercent)
                        .stroke(
                            AngularGradient(colors: [.orange, .red, .orange], center: .center),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(monitor.storageInfo.usedPercent * 100))%")
                            .font(.title.bold())
                        Text("已用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    storageLegend(label: "总容量", value: monitor.storageInfo.total, color: .gray)
                    storageLegend(label: "已用", value: monitor.storageInfo.used, color: .orange)
                    storageLegend(label: "剩余", value: monitor.storageInfo.available, color: .secondary.opacity(0.2))
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func storageLegend(label: String, value: Int64, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: value, countStyle: .file))
                .bold()
        }
        .font(.caption)
        .frame(width: 150)
    }
    
    private var batteryCard: some View {
        VStack(alignment: .leading) {
            Text("电池状态").font(.headline)
            
            Spacer()
            
            HStack(spacing: 20) {
                ZStack {
                    Image(systemName: "battery.100")
                        .font(.system(size: 80))
                        .foregroundColor(.green.opacity(0.2))
                    
                    Text("\(monitor.batteryInfo.level)%")
                        .font(.title.bold())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(monitor.batteryInfo.status, systemImage: "bolt.fill")
                        .foregroundColor(.orange)
                    Label("\(String(format: "%.1f", monitor.batteryInfo.temperature))°C", systemImage: "thermometer.medium")
                        .foregroundColor(.blue)
                    Label(monitor.batteryInfo.health, systemImage: "heart.fill")
                        .foregroundColor(.red)
                }
                .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
