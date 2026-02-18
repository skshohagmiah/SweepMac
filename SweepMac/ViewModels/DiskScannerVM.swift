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

        let totalCategories = Double(categories.count)

        for i in categories.indices {
            categories[i].isScanning = true

            let (size, files) = await scanner.scanCategory(categories[i].type)

            categories[i].totalSize = size
            categories[i].files = files
            categories[i].isScanning = false

            scanProgress = Double(i + 1) / totalCategories
        }

        totalCleanableSize = categories
            .filter { $0.safeToClean }
            .reduce(0) { $0 + $1.totalSize }

        refreshDiskInfo()
        lastScanDate = Date()
        isScanning = false
    }

    func scanCategory(_ type: CleanCategoryType) async {
        guard let index = categories.firstIndex(where: { $0.type == type }) else { return }

        categories[index].isScanning = true
        let (size, files) = await scanner.scanCategory(type)
        categories[index].totalSize = size
        categories[index].files = files
        categories[index].isScanning = false

        totalCleanableSize = categories
            .filter { $0.safeToClean }
            .reduce(0) { $0 + $1.totalSize }
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
}
