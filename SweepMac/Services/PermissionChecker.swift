import Foundation
import AppKit

struct PermissionChecker {
    static func hasFullDiskAccess() -> Bool {
        // Try to read a protected directory that requires Full Disk Access
        let testPaths = [
            NSHomeDirectory() + "/Library/Mail",
            NSHomeDirectory() + "/Library/Safari",
            "/Library/Application Support/com.apple.TCC/TCC.db"
        ]

        for path in testPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }

        // Fallback: try to list a protected directory
        let protectedPath = NSHomeDirectory() + "/Library/Mail"
        if let _ = try? FileManager.default.contentsOfDirectory(atPath: protectedPath) {
            return true
        }

        // If none of the protected paths are accessible, we likely don't have FDA
        // But also check if those paths exist at all
        for path in testPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Path exists but we can't read it => no FDA
                return false
            }
        }

        // If protected paths don't exist, we can't definitively tell.
        // Assume we have access since basic scanning will work.
        return true
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
