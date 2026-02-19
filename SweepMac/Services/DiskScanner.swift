import Foundation

actor DiskScanner {
    private let fileManager = FileManager.default

    // Track scanned paths across categories to avoid double-counting
    private var scannedPaths: Set<String> = []

    func resetScannedPaths() {
        scannedPaths.removeAll()
    }

    func scanCategory(_ categoryType: CleanCategoryType) async -> (Int64, [FileItem]) {
        switch categoryType {
        case .nodeModules:
            return await scanForNodeModules(in: categoryType.scanPaths)
        case .largeFiles:
            return await scanForLargeFiles(in: categoryType.scanPaths)
        case .downloads:
            return await scanDownloads(in: categoryType.scanPaths)
        case .systemData:
            return await scanSystemData()
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

            // Skip if this path was already scanned as part of a parent
            if scannedPaths.contains(where: { path.hasPrefix($0 + "/") }) { continue }
            scannedPaths.insert(path)

            let (size, dirItems) = scanDirectory(at: path)
            totalSize += size
            items.append(contentsOf: dirItems)
        }

        items.sort { $0.size > $1.size }
        return (totalSize, items)
    }

    private func scanDirectory(at path: String) -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, [])
        }

        var topLevelSizes: [String: Int64] = [:]
        var topLevelDates: [String: Date] = [:]
        var topLevelIsDir: [String: Bool] = [:]

        while let url = enumerator.nextObject() as? URL {
            guard let resourceValues = try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey
            ]) else { continue }

            // Skip symlinks to avoid cycles and double-counting
            if resourceValues.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }

            let fileSize = Int64(resourceValues.totalFileAllocatedSize ?? 0)
            let modDate = resourceValues.contentModificationDate ?? Date.distantPast
            let isDir = resourceValues.isDirectory ?? false

            let relativePath = url.path.replacingOccurrences(of: path + "/", with: "")
            let topLevel = relativePath.components(separatedBy: "/").first ?? relativePath
            let topLevelPath = (path as NSString).appendingPathComponent(topLevel)

            topLevelSizes[topLevelPath, default: 0] += fileSize
            totalSize += fileSize

            if topLevelDates[topLevelPath] == nil {
                topLevelDates[topLevelPath] = modDate
                topLevelIsDir[topLevelPath] = isDir
            }

            if !relativePath.contains("/") {
                topLevelIsDir[topLevelPath] = isDir
                topLevelDates[topLevelPath] = modDate
            }
        }

        for (itemPath, size) in topLevelSizes where size > 0 {
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
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard let resourceValues = try? url.resourceValues(forKeys: [
                    .totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey
                ]) else { continue }

                if resourceValues.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }

                let isDir = resourceValues.isDirectory ?? false
                if isDir {
                    let name = url.lastPathComponent
                    if ["node_modules", ".Trash", "DerivedData", "Library", ".git", "Caches", "CoreSimulator"].contains(name) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let size = Int64(resourceValues.totalFileAllocatedSize ?? 0)
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
        return (totalSize, Array(items.prefix(50)))
    }

    private func scanDownloads(in paths: [String]) async -> (Int64, [FileItem]) {
        var totalSize: Int64 = 0
        var items: [FileItem] = []
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                guard let resourceValues = try? url.resourceValues(forKeys: [
                    .totalFileAllocatedSizeKey, .contentModificationDateKey, .isDirectoryKey
                ]) else { continue }

                let modDate = resourceValues.contentModificationDate ?? Date()
                let isDir = resourceValues.isDirectory ?? false
                let size: Int64

                if isDir {
                    size = directorySize(at: url.path)
                } else {
                    size = Int64(resourceValues.totalFileAllocatedSize ?? 0)
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

    private func scanSystemData() async -> (Int64, [FileItem]) {
        let home = NSHomeDirectory()
        var items: [FileItem] = []
        var totalSize: Int64 = 0

        // Scan individual apps inside Application Support (the big one)
        let appSupportPath = "\(home)/Library/Application Support"
        if fileManager.fileExists(atPath: appSupportPath),
           let contents = try? fileManager.contentsOfDirectory(atPath: appSupportPath) {
            for item in contents where !item.hasPrefix(".") {
                let itemPath = (appSupportPath as NSString).appendingPathComponent(item)
                // Skip MobileSync — that's in iOS Backups category
                if item == "MobileSync" { continue }
                let size = directorySize(at: itemPath)
                if size > 10_000_000 { // Only show > 10 MB
                    totalSize += size
                    let modDate = (try? fileManager.attributesOfItem(atPath: itemPath)[.modificationDate] as? Date) ?? Date.distantPast
                    items.append(FileItem(
                        path: itemPath,
                        name: item,
                        size: size,
                        modifiedDate: modDate,
                        isDirectory: true
                    ))
                }
            }
        }

        // Other system data locations
        let otherPaths: [(String, String)] = [
            ("\(home)/Library/Containers", "App Containers"),
            ("\(home)/Library/Group Containers", "Group Containers"),
            ("\(home)/Library/Saved Application State", "Saved App State"),
            ("\(home)/Library/WebKit", "WebKit Data"),
        ]

        for (path, label) in otherPaths {
            guard fileManager.fileExists(atPath: path) else { continue }
            if scannedPaths.contains(where: { path.hasPrefix($0 + "/") }) { continue }

            let size = directorySize(at: path)
            if size > 1_000_000 {
                totalSize += size
                let modDate = (try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date.distantPast
                items.append(FileItem(
                    path: path,
                    name: label,
                    size: size,
                    modifiedDate: modDate,
                    isDirectory: true
                ))
            }
        }

        items.sort { $0.size > $1.size }
        return (totalSize, Array(items.prefix(50)))
    }

    /// Scans the immediate children of a directory (one level deep).
    /// For child directories, computes their total recursive size.
    func scanChildren(of directoryPath: String) async -> [FileItem] {
        guard SafePathValidator.isSafe(directoryPath) else { return [] }
        guard fileManager.fileExists(atPath: directoryPath) else { return [] }

        let dirURL = URL(fileURLWithPath: directoryPath)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [
                .totalFileAllocatedSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [FileItem] = []

        for url in contents {
            guard let resourceValues = try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .isSymbolicLinkKey
            ]) else { continue }

            if resourceValues.isSymbolicLink == true { continue }

            let isDir = resourceValues.isDirectory ?? false
            let modDate = resourceValues.contentModificationDate ?? Date.distantPast
            let size: Int64

            if isDir {
                size = directorySize(at: url.path)
            } else {
                size = Int64(resourceValues.totalFileAllocatedSize ?? 0)
            }

            guard size > 0 else { continue }

            items.append(FileItem(
                path: url.path,
                name: url.lastPathComponent,
                size: size,
                modifiedDate: modDate,
                isDirectory: isDir
            ))
        }

        items.sort { $0.size > $1.size }
        return items
    }

    private func directorySize(at path: String) -> Int64 {
        var size: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isSymbolicLinkKey]) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if let fileSize = values.totalFileAllocatedSize {
                size += Int64(fileSize)
            }
        }
        return size
    }
}
