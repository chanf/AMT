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

    var isText: Bool {
        let textExtensions = ["txt", "json", "xml", "md", "csv", "log", "swift", "py", "java", "kt", "html", "css", "js", "sh", "yaml", "yml"]
        let ext = (name as NSString).pathExtension.lowercased()
        return textExtensions.contains(ext)
    }

    var isAudio: Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg"]
        let ext = (name as NSString).pathExtension.lowercased()
        return audioExtensions.contains(ext)
    }

    var isAPK: Bool {
        return (name as NSString).pathExtension.lowercased() == "apk"
    }
}

/// Represents an installed application on an Android device.
struct AndroidApp: Identifiable, Hashable {
    var id: String { packageName }
    let packageName: String
    var name: String? = nil
    var remotePath: String? = nil
    var versionName: String? = nil
    var versionCode: String? = nil
    var iconURL: URL? = nil
}
