import Foundation

actor DiskScanner {
    private let fileManager = FileManager.default

    func scanCategory(_ categoryType: CleanCategoryType) async -> (Int64, [FileItem]) {
        switch categoryType {
        case .nodeModules:
            return await scanForNodeModules(in: categoryType.scanPaths)
        case .largeFiles:
            return await scanForLargeFiles(in: categoryType.scanPaths)
        case .downloads:
            return await scanDownloads(in: categoryType.scanPaths)
        default:
            return await scanDirectories(categoryType.scanPaths)
        }
    }

    private func scanDirectories(_ paths: [String]) async -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []

        for path in paths {
            guard SafePathValidator.isSafe(path) else { continue }
            guard fileManager.fileExists(atPath: path) else { continue }

            let (size, dirItems) = scanDirectory(at: path, maxDepth: 1)
            totalSize += size
            items.append(contentsOf: dirItems)
        }

        items.sort { $0.size > $1.size }
        return (totalSize, items)
    }

    private func scanDirectory(at path: String, maxDepth: Int) -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, [])
        }

        // Collect top-level items with their sizes
        var topLevelSizes: [String: Int64] = [:]
        var topLevelDates: [String: Date] = [:]
        var topLevelIsDir: [String: Bool] = [:]

        while let url = enumerator.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [
                .fileSizeKey, .contentModificationDateKey, .isDirectoryKey
            ]) else { continue }

            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let modDate = resourceValues.contentModificationDate ?? Date.distantPast
            let isDir = resourceValues.isDirectory ?? false

            // Determine top-level item
            let relativePath = url.path.replacingOccurrences(of: path + "/", with: "")
            let topLevel = relativePath.components(separatedBy: "/").first ?? relativePath
            let topLevelPath = (path as NSString).appendingPathComponent(topLevel)

            topLevelSizes[topLevelPath, default: 0] += fileSize
            totalSize += fileSize

            if topLevelDates[topLevelPath] == nil {
                topLevelDates[topLevelPath] = modDate
                topLevelIsDir[topLevelPath] = isDir
            }

            // Check if this is the top-level item itself
            if !relativePath.contains("/") {
                topLevelIsDir[topLevelPath] = isDir
                topLevelDates[topLevelPath] = modDate
            }
        }

        for (itemPath, size) in topLevelSizes {
            let name = (itemPath as NSString).lastPathComponent
            items.append(FileItem(
                path: itemPath,
                name: name,
                size: size,
                modifiedDate: topLevelDates[itemPath] ?? Date.distantPast,
                isDirectory: topLevelIsDir[itemPath] ?? false
            ))
        }

        return (totalSize, items)
    }

    private func scanForNodeModules(in searchPaths: [String]) async -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath) else { continue }

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if url.lastPathComponent == "node_modules" {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir {
                        enumerator.skipDescendants()
                        let dirSize = directorySize(at: url.path)
                        totalSize += dirSize
                        items.append(FileItem(
                            path: url.path,
                            name: "node_modules (\(url.deletingLastPathComponent().lastPathComponent))",
                            size: dirSize,
                            modifiedDate: (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date.distantPast,
                            isDirectory: true
                        ))
                    }
                }

                // Limit search depth to avoid scanning too deeply
                let depth = url.pathComponents.count - URL(fileURLWithPath: searchPath).pathComponents.count
                if depth > 5 {
                    enumerator.skipDescendants()
                }
            }
        }

        items.sort { $0.size > $1.size }
        return (totalSize, items)
    }

    private func scanForLargeFiles(in searchPaths: [String]) async -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []
        let threshold: Int64 = 500 * 1024 * 1024 // 500 MB

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath) else { continue }

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard let resourceValues = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey, .isDirectoryKey
                ]) else { continue }

                let isDir = resourceValues.isDirectory ?? false
                if isDir {
                    // Skip certain large directories we scan elsewhere
                    let name = url.lastPathComponent
                    if ["node_modules", ".Trash", "DerivedData", "Library"].contains(name) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let size = Int64(resourceValues.fileSize ?? 0)
                if size >= threshold {
                    totalSize += size
                    items.append(FileItem(
                        path: url.path,
                        name: url.lastPathComponent,
                        size: size,
                        modifiedDate: resourceValues.contentModificationDate ?? Date.distantPast,
                        isDirectory: false
                    ))
                }
            }
        }

        items.sort { $0.size > $1.size }
        return (totalSize, Array(items.prefix(100))) // Limit to top 100
    }

    private func scanDownloads(in paths: [String]) async -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                guard let resourceValues = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey, .isDirectoryKey
                ]) else { continue }

                let modDate = resourceValues.contentModificationDate ?? Date()
                let isDir = resourceValues.isDirectory ?? false
                let size: Int64

                if isDir {
                    size = directorySize(at: url.path)
                } else {
                    size = Int64(resourceValues.fileSize ?? 0)
                }

                if modDate < thirtyDaysAgo {
                    totalSize += size
                    items.append(FileItem(
                        path: url.path,
                        name: url.lastPathComponent,
                        size: size,
                        modifiedDate: modDate,
                        isDirectory: isDir
                    ))
                }
            }
        }

        items.sort { $0.size > $1.size }
        return (totalSize, items)
    }

    private func directorySize(at path: String) -> Int64 {
        var size: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        while let url = enumerator.nextObject() as? URL {
            if let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }
}
