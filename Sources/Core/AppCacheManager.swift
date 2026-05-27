import Foundation

class AppCacheManager {
    static let shared = AppCacheManager()
    private let cacheFile: URL
    private var cache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.example.androidfile.cache")

    private init() {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AndroidFile")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cacheFile = folder.appendingPathComponent("app_names.json")
        load()
    }

    func getName(for packageName: String) -> String? {
        return queue.sync { cache[packageName] }
    }

    func saveName(_ name: String, for packageName: String) {
        queue.async {
            self.cache[packageName] = name
            self.persist()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        cache = json
    }

    private func persist() {
        guard let data = try? JSONSerialization.data(withJSONObject: cache, options: .prettyPrinted) else { return }
        try? data.write(to: cacheFile)
    }
}
