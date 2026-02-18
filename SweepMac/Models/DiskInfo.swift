import Foundation

struct DiskInfo {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var usageLevel: UsageLevel {
        switch usedPercentage {
        case ..<60: return .healthy
        case ..<80: return .warning
        default: return .critical
        }
    }

    enum UsageLevel {
        case healthy, warning, critical
    }

    static func current() -> DiskInfo {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let totalSize = attrs[.systemSize] as? Int64,
              let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return DiskInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0)
        }
        return DiskInfo(
            totalSpace: totalSize,
            usedSpace: totalSize - freeSize,
            freeSpace: freeSize
        )
    }
}
