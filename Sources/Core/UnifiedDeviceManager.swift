import Foundation
import Combine

class UnifiedDeviceManager: ObservableObject {
    @Published var connectedDevices: [AndroidDevice] = []
    
    private let adbManager = ADBDeviceManager()
    private let mtpManager = MTPDeviceManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Merge devices from both sources
        Publishers.CombineLatest(adbManager.$connectedDevices, mtpManager.$connectedDevices)
            .map { adbDevices, mtpDevices in
                return adbDevices + mtpDevices
            }
            .assign(to: \.connectedDevices, on: self)
            .store(in: &cancellables)
    }

    func startDiscovery() {
        adbManager.startDiscovery()
        mtpManager.startDiscovery()
    }

    func stopDiscovery() {
        adbManager.stopDiscovery()
        mtpManager.stopDiscovery()
    }
}
