import Foundation
import AppKit

actor Cleaner {
    enum CleanResult {
        case success(freedBytes: Int64)
        case partialSuccess(freedBytes: Int64, errors: [String])
        case failure(Error)
    }

    enum CleanError: LocalizedError {
        case unsafePath(String)
        case permissionDenied(String)
        case fileNotFound(String)
        case dangerousSymlink(String)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .unsafePath(let path): return "Blocked unsafe path: \(path)"
            case .permissionDenied(let path): return "Permission denied: \(path)"
            case .fileNotFound(let path): return "File not found: \(path)"
            case .dangerousSymlink(let path): return "Dangerous symlink detected: \(path)"
            case .unknown(let msg): return msg
            }
        }
    }

    private let fileManager = FileManager.default

    func cleanFiles(_ files: [FileItem], moveToTrash: Bool = true) async -> CleanResult {
        var freedBytes: Int64 = 0
        var errors: [String] = []

        for file in files {
            // TOCTOU protection: re-resolve and re-validate at deletion time
            let resolvedPath = (file.path as NSString).resolvingSymlinksInPath
            guard SafePathValidator.isSafe(resolvedPath) else {
                errors.append("Skipped unsafe path: \(file.path)")
                continue
            }

            // Check for dangerous symlinks
            guard SafePathValidator.isNotDangerousSymlink(file.path) else {
                errors.append("Skipped dangerous symlink: \(file.path)")
                continue
            }

            // Verify file still exists
            guard fileManager.fileExists(atPath: file.path) else {
                errors.append("File no longer exists: \(file.name)")
                continue
            }

            do {
                if moveToTrash {
                    try await moveToTrashAsync(url: file.url)
                } else {
                    try fileManager.removeItem(at: file.url)
                }
                freedBytes += file.size
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
                errors.append("\(file.name): Permission denied")
            } catch {
                errors.append("\(file.name): \(error.localizedDescription)")
            }
        }

        if errors.isEmpty {
            return .success(freedBytes: freedBytes)
        } else if freedBytes > 0 {
            return .partialSuccess(freedBytes: freedBytes, errors: errors)
        } else {
            return .failure(CleanError.unknown("Failed to clean any files"))
        }
    }

    func cleanCategory(_ category: CleanCategory, moveToTrash: Bool = true) async -> CleanResult {
        let selectedFiles = category.files.filter { $0.isSelected }
        let filesToClean = selectedFiles.isEmpty ? category.files : selectedFiles
        return await cleanFiles(filesToClean, moveToTrash: moveToTrash)
    }

    func emptyTrash() async -> CleanResult {
        let trashPath = NSHomeDirectory() + "/.Trash"
        guard let contents = try? fileManager.contentsOfDirectory(atPath: trashPath) else {
            return .success(freedBytes: 0)
        }

        var freedBytes: Int64 = 0
        var errors: [String] = []

        for item in contents {
            let itemPath = (trashPath as NSString).appendingPathComponent(item)

            // Validate each trash item before deletion
            guard SafePathValidator.isNotDangerousSymlink(itemPath) else {
                errors.append("\(item): Skipped dangerous symlink")
                continue
            }

            do {
                let attrs = try fileManager.attributesOfItem(atPath: itemPath)
                let size = (attrs[.size] as? Int64) ?? 0
                try fileManager.removeItem(atPath: itemPath)
                freedBytes += size
            } catch {
                errors.append("\(item): \(error.localizedDescription)")
            }
        }

        if errors.isEmpty {
            return .success(freedBytes: freedBytes)
        } else {
            return .partialSuccess(freedBytes: freedBytes, errors: errors)
        }
    }

    @MainActor
    private func moveToTrashAsync(url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
