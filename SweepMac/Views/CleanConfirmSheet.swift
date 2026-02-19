import SwiftUI

struct CleanConfirmSheet: View {
    @ObservedObject var cleanerVM: CleanerVM
    @ObservedObject var scannerVM: DiskScannerVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Confirm Cleanup")
                .font(.title2.weight(.semibold))

            if let action = cleanerVM.pendingCleanAction {
                Text(action.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // File preview list
            if let action = cleanerVM.pendingCleanAction {
                filePreview(for: action)
            }

            HStack(spacing: 8) {
                Image(systemName: cleanerVM.moveToTrash ? "trash" : "xmark.bin")
                Text(cleanerVM.moveToTrash
                     ? "Files will be moved to Trash (recoverable)"
                     : "Files will be permanently deleted")
                    .font(.caption)
                    .foregroundStyle(cleanerVM.moveToTrash ? Color.secondary : Color.red)
            }
            .padding(8)
            .background(
                (cleanerVM.moveToTrash ? Color.secondary : Color.red)
                    .opacity(0.1),
                in: RoundedRectangle(cornerRadius: 8)
            )

            HStack(spacing: 16) {
                Button("Cancel") {
                    cleanerVM.showConfirmation = false
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Clean Now") {
                    Task {
                        await cleanerVM.confirmClean(scannerVM: scannerVM)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 440)
    }

    @ViewBuilder
    private func filePreview(for action: CleanerVM.CleanAction) -> some View {
        let previewBackground = colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.96)

        switch action {
        case .selectedFiles(let files):
            fileListPreview(files: files, background: previewBackground)

        case .category(let category):
            fileListPreview(files: Array(category.files.prefix(10)), background: previewBackground, totalCount: category.files.count)

        case .allCategories(let categories):
            let safeCategories = categories.filter { $0.safeToClean && $0.totalSize > 0 }
            if !safeCategories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(safeCategories) { cat in
                        HStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .font(.caption)
                                .foregroundStyle(cat.color)
                                .frame(width: 16)
                            Text(cat.name)
                                .font(.caption)
                            Spacer()
                            Text("\(cat.files.count) items")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(ByteFormatter.format(cat.totalSize))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(previewBackground, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func fileListPreview(files: [FileItem], background: Color, totalCount: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(files.prefix(8)) { file in
                HStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                    Text(file.name)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(ByteFormatter.format(file.size))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            let count = totalCount ?? files.count
            if count > 8 {
                Text("and \(count - 8) more...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
    }
}
