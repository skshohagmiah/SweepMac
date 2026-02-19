import Foundation

struct ScanSnapshot: Codable, Identifiable {
    let id: UUID
    let date: Date
    let totalCleanableSize: Int64
    let categorySizes: [String: Int64]

    init(totalCleanable: Int64, categories: [CleanCategory]) {
        self.id = UUID()
        self.date = Date()
        self.totalCleanableSize = totalCleanable
        var sizes: [String: Int64] = [:]
        for cat in categories {
            sizes[cat.type.rawValue] = cat.totalSize
        }
        self.categorySizes = sizes
    }

    // MARK: - Persistence

    private static let storageKey = "scanSnapshots"
    private static let maxSnapshots = 30

    static func save(totalCleanable: Int64, categories: [CleanCategory]) {
        let snapshot = ScanSnapshot(totalCleanable: totalCleanable, categories: categories)
        var existing = loadAll()
        existing.append(snapshot)
        // Keep only the last N snapshots
        if existing.count > maxSnapshots {
            existing = Array(existing.suffix(maxSnapshots))
        }
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func loadAll() -> [ScanSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshots = try? JSONDecoder().decode([ScanSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }
}
