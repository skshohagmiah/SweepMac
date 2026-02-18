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
        "/cores"
    ]

    private static let blockedPatterns: [String] = [
        "/System/",
        "/.vol/",
        "/Volumes/Recovery",
        "com.apple.boot",
    ]

    static func isSafe(_ path: String) -> Bool {
        let resolved = (path as NSString).resolvingSymlinksInPath

        for blocked in blockedPaths {
            if resolved == blocked || resolved.hasPrefix(blocked + "/") {
                return false
            }
        }

        for pattern in blockedPatterns {
            if resolved.contains(pattern) {
                return false
            }
        }

        // Must be under user home or known Library paths
        let home = NSHomeDirectory()
        let allowedRoots = [
            home,
            "/Library/Caches",
            "/Library/Logs",
            "/tmp"
        ]

        return allowedRoots.contains { resolved.hasPrefix($0) }
    }

    static func validatePaths(_ paths: [String]) -> [String] {
        paths.filter { isSafe($0) }
    }
}
