import Foundation

/// Represents a connected Android device.
struct AndroidDevice: Identifiable, Hashable {
    let id: String
    let model: String
    let serial: String
    let connectionType: ConnectionType

    enum ConnectionType: String {
        case adb
        case mtp
    }
}

/// Represents a file or folder on an Android device.
struct AndroidFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?

    var extensionName: String {
        return (name as NSString).pathExtension
    }
}
