import Foundation

struct CachedUsage: Codable {
    let data: UsageResponse
    let timestamp: Date
}

class UsageCache {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Jessep", isDirectory: true)

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        fileURL = appFolder.appendingPathComponent("usage_cache.json")
    }

    func save(_ data: UsageResponse?) {
        guard let data = data else { return }

        let cached = CachedUsage(data: data, timestamp: Date())

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(cached)
            try jsonData.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to cache usage data: \(error)")
        }
    }

    func load() -> CachedUsage? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedUsage.self, from: data)
        } catch {
            return nil
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var age: TimeInterval? {
        load().map { Date().timeIntervalSince($0.timestamp) }
    }

    var isStale: Bool {
        guard let age = age else { return true }
        return age > 3600 // Stale after 1 hour
    }

    var isVeryStale: Bool {
        guard let age = age else { return true }
        return age > 86400 // Very stale after 24 hours
    }
}
