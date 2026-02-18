import Foundation

struct ByteFormatter {
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return f
    }()

    static func format(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    static func shortFormat(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useMB, .useGB, .useTB]
        return f.string(fromByteCount: bytes)
    }
}
