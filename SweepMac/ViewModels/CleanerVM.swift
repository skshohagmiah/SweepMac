import Foundation
import SwiftUI

@MainActor
class CleanerVM: ObservableObject {
    @Published var isCleaning: Bool = false
    @Published var cleanProgress: Double = 0
    @Published var lastResult: CleanResultInfo?
    @Published var showConfirmation: Bool = false
    @Published var showResult: Bool = false
    @Published var pendingCleanAction: CleanAction?

    private let cleaner = Cleaner()

    struct CleanResultInfo: Identifiable {
        let id = UUID()
        let freedBytes: Int64
        let errors: [String]
        let isSuccess: Bool
        let categoryBreakdown: [(name: String, freedBytes: Int64)]

        var message: String {
            if isSuccess {
                return "Freed \(ByteFormatter.format(freedBytes)) of space!"
            } else if freedBytes > 0 {
                return "Freed \(ByteFormatter.format(freedBytes)) with \(errors.count) error(s)"
            } else {
                return "Cleaning failed: \(errors.first ?? "Unknown error")"
            }
        }

        var breakdownSummary: String? {
            guard categoryBreakdown.count > 1 else { return nil }
            return categoryBreakdown
                .filter { $0.freedBytes > 0 }
                .map { "\($0.name): \(ByteFormatter.format($0.freedBytes))" }
                .joined(separator: "\n")
        }
    }

    enum CleanAction {
        case category(CleanCategory)
        case allCategories([CleanCategory])
        case selectedFiles([FileItem])

        var description: String {
            switch self {
            case .category(let cat):
                return "Clean \(cat.name) (\(ByteFormatter.format(cat.totalSize)))?"
            case .allCategories(let cats):
                let total = cats.reduce(Int64(0)) { $0 + $1.totalSize }
                return "Clean all safe categories (\(ByteFormatter.format(total)))?"
            case .selectedFiles(let files):
                let total = files.reduce(Int64(0)) { $0 + $1.size }
                return "Delete \(files.count) selected items (\(ByteFormatter.format(total)))?"
            }
        }
    }

    @AppStorage("moveToTrash") var moveToTrash: Bool = true

    func requestClean(action: CleanAction) {
        pendingCleanAction = action
        showConfirmation = true
    }

    func confirmClean(scannerVM: DiskScannerVM) async {
        guard let action = pendingCleanAction else { return }
        showConfirmation = false
        isCleaning = true
        cleanProgress = 0

        var totalFreed: Int64 = 0
        var allErrors: [String] = []
        var breakdown: [(name: String, freedBytes: Int64)] = []

        switch action {
        case .category(let category):
            let result = await cleaner.cleanCategory(category, moveToTrash: moveToTrash)
            var freed: Int64 = 0
            processResult(result, freed: &freed, errors: &allErrors)
            totalFreed += freed
            breakdown.append((name: category.name, freedBytes: freed))

        case .allCategories(let categories):
            let safeCategories = categories.filter { $0.safeToClean && $0.totalSize > 0 }
            for (i, category) in safeCategories.enumerated() {
                let result = await cleaner.cleanCategory(category, moveToTrash: moveToTrash)
                var freed: Int64 = 0
                processResult(result, freed: &freed, errors: &allErrors)
                totalFreed += freed
                breakdown.append((name: category.name, freedBytes: freed))
                cleanProgress = Double(i + 1) / Double(safeCategories.count)
            }

        case .selectedFiles(let files):
            let result = await cleaner.cleanFiles(files, moveToTrash: moveToTrash)
            var freed: Int64 = 0
            processResult(result, freed: &freed, errors: &allErrors)
            totalFreed += freed
        }

        lastResult = CleanResultInfo(
            freedBytes: totalFreed,
            errors: allErrors,
            isSuccess: allErrors.isEmpty,
            categoryBreakdown: breakdown
        )

        isCleaning = false
        showResult = true

        // Rescan to update sizes
        await scannerVM.scanAll()
    }

    private func processResult(_ result: Cleaner.CleanResult, freed: inout Int64, errors: inout [String]) {
        switch result {
        case .success(let bytes):
            freed += bytes
        case .partialSuccess(let bytes, let errs):
            freed += bytes
            errors.append(contentsOf: errs)
        case .failure(let error):
            errors.append(error.localizedDescription)
        }
    }
}
