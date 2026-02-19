import Foundation
import SwiftUI

@MainActor
class DiskScannerVM: ObservableObject {
    @Published var diskInfo: DiskInfo = DiskInfo.current()
    @Published var categories: [CleanCategory] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var lastScanDate: Date?
    @Published var totalCleanableSize: Int64 = 0
    @Published var hasFullDiskAccess: Bool = true
    @Published var selectedCategory: CleanCategoryType?
    @Published var fileNodes: [CleanCategoryType: [FileNode]] = [:]

    private let scanner = DiskScanner()

    init() {
        initializeCategories()
        checkPermissions()
    }

    private func initializeCategories() {
        categories = CleanCategoryType.allCases.map { CleanCategory(type: $0) }
    }

    func checkPermissions() {
        hasFullDiskAccess = PermissionChecker.hasFullDiskAccess()
    }

    func refreshDiskInfo() {
        diskInfo = DiskInfo.current()
    }

    func scanAll() async {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        totalCleanableSize = 0

        // Reset path tracking so we don't double-count between categories
        await scanner.resetScannedPaths()

        let totalCategories = Double(categories.count)

        for i in categories.indices {
            categories[i].isScanning = true
            categories[i].scanError = nil

            let (size, files) = await scanner.scanCategory(categories[i].type)

            categories[i].totalSize = size
            categories[i].files = files
            categories[i].isScanning = false

            if files.isEmpty && size == 0 && !categories[i].type.scanPaths.isEmpty {
                let hasAccess = categories[i].type.scanPaths.allSatisfy {
                    FileManager.default.isReadableFile(atPath: $0)
                }
                if !hasAccess {
                    categories[i].scanError = "Permission denied. Ensure Full Disk Access is enabled."
                }
            }

            buildNodes(for: categories[i].type)
            scanProgress = Double(i + 1) / totalCategories
        }

        recalculateCleanableSize()
        refreshDiskInfo()
        lastScanDate = Date()
        isScanning = false

        // Save scan snapshot for history
        ScanSnapshot.save(totalCleanable: totalCleanableSize, categories: categories)
    }

    func scanCategory(_ type: CleanCategoryType) async {
        guard let index = categories.firstIndex(where: { $0.type == type }) else { return }

        categories[index].isScanning = true
        let (size, files) = await scanner.scanCategory(type)
        categories[index].totalSize = size
        categories[index].files = files
        categories[index].isScanning = false
        buildNodes(for: type)

        recalculateCleanableSize()
    }

    private func recalculateCleanableSize() {
        let raw = categories.reduce(Int64(0)) { $0 + $1.totalSize }
        // Never report more cleanable than actual used space
        totalCleanableSize = min(raw, diskInfo.usedSpace)
    }

    func category(for type: CleanCategoryType) -> CleanCategory? {
        categories.first { $0.type == type }
    }

    func toggleFileSelection(categoryType: CleanCategoryType, fileID: UUID) {
        guard let catIndex = categories.firstIndex(where: { $0.type == categoryType }),
              let fileIndex = categories[catIndex].files.firstIndex(where: { $0.id == fileID }) else { return }
        categories[catIndex].files[fileIndex].isSelected.toggle()
    }

    func selectAllFiles(categoryType: CleanCategoryType, selected: Bool) {
        guard let catIndex = categories.firstIndex(where: { $0.type == categoryType }) else { return }
        for i in categories[catIndex].files.indices {
            categories[catIndex].files[i].isSelected = selected
        }
    }

    var lastScanFormatted: String {
        guard let date = lastScanDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Hierarchical Browsing

    private func buildNodes(for categoryType: CleanCategoryType) {
        guard let category = category(for: categoryType) else { return }
        fileNodes[categoryType] = category.files.map { FileNode(fileItem: $0) }
    }

    func expandNode(_ node: FileNode) async {
        guard node.isDirectory else { return }

        if node.hasLoadedChildren {
            node.isExpanded.toggle()
            objectWillChange.send()
            return
        }

        node.isLoadingChildren = true
        objectWillChange.send()

        let childItems = await scanner.scanChildren(of: node.path)

        let childNodes = childItems.map { item in
            FileNode(fileItem: item, parent: node)
        }

        node.children = childNodes
        node.isLoadingChildren = false
        node.isExpanded = true
        objectWillChange.send()
    }

    func collapseNode(_ node: FileNode) {
        node.isExpanded = false
        objectWillChange.send()
    }

    func toggleNodeSelection(_ node: FileNode) {
        node.isSelected.toggle()
        objectWillChange.send()
    }

    func selectAllNodes(categoryType: CleanCategoryType, selected: Bool) {
        guard let nodes = fileNodes[categoryType] else { return }
        for node in nodes {
            node.isSelected = selected
            if let children = node.children, node.isExpanded {
                for child in children {
                    child.isSelected = selected
                }
            }
        }
        objectWillChange.send()
    }

    func selectedFileItems(for categoryType: CleanCategoryType) -> [FileItem] {
        guard let nodes = fileNodes[categoryType] else { return [] }
        var result: [FileItem] = []
        collectSelected(from: nodes, into: &result)
        return result
    }

    private func collectSelected(from nodes: [FileNode], into result: inout [FileItem]) {
        for node in nodes {
            if node.isSelected {
                result.append(node.fileItem)
            } else if let children = node.children {
                collectSelected(from: children, into: &result)
            }
        }
    }
}
