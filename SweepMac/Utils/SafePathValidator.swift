import Foundation

struct SafePathValidator {
    private static let blockedPaths: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/var",
        "/private/var",
        "/Library/Apple",
        "/Library/SystemMigration",
        "/Applications",
        "/cores",
        "/private/tmp",
        "/tmp"
    ]

    private static let blockedPatterns: [String] = [
        "/System/",
        "/.vol/",
        "/Volumes/Recovery",
        "com.apple.boot",
        "../",
    ]

    /// Maximum allowed path depth to prevent traversal attacks.
    private static let maxPathDepth = 15

    static func isSafe(_ path: String) -> Bool {
        // Resolve symlinks and canonicalize
        let resolved = (path as NSString).standardizingPath
        let canonical = (resolved as NSString).resolvingSymlinksInPath

        // Reject excessively deep paths
        let components = canonical.components(separatedBy: "/").filter { !$0.isEmpty }
        guard components.count <= maxPathDepth else { return false }

        // Check blocked paths
        for blocked in blockedPaths {
            if canonical == blocked || canonical.hasPrefix(blocked + "/") {
                return false
            }
        }

        // Check blocked patterns
        for pattern in blockedPatterns {
            if canonical.contains(pattern) {
                return false
            }
        }

        // Must be under user home directory only
        let home = NSHomeDirectory()
        return canonical.hasPrefix(home + "/") || canonical == home
    }

    /// Returns true if the path is not a symlink pointing outside its parent.
    static func isNotDangerousSymlink(_ path: String) -> Bool {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let type = attrs[.type] as? FileAttributeType else {
            return true
        }
        if type == .typeSymbolicLink {
            let resolved = (path as NSString).resolvingSymlinksInPath
            return isSafe(resolved)
        }
        return true
    }

    static func validatePaths(_ paths: [String]) -> [String] {
        paths.filter { isSafe($0) }
    }
}
