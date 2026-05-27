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
        return (name as NSString).pathExtension.lowercased()
    }

    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "heic", "bmp", "tiff", "tif"]
        let ext = (name as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    var isVideo: Bool {
        let videoExtensions = ["mp4", "m4v", "mov", "avi", "mkv", "webm"]
        let ext = (name as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
}
