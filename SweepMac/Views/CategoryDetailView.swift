import SwiftUI

struct CategoryDetailView: View {
    let categoryType: CleanCategoryType
    @ObservedObject var scannerVM: DiskScannerVM
    @ObservedObject var cleanerVM: CleanerVM

    private var category: CleanCategory? {
        scannerVM.category(for: categoryType)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if let category = category {
                if category.isScanning {
                    scanningView
                } else if category.files.isEmpty {
                    emptyView
                } else {
                    fileListView(category: category)
                }
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: categoryType.icon)
                .font(.largeTitle)
                .foregroundStyle(categoryType.color)
                .frame(width: 48, height: 48)
                .background(categoryType.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryType.rawValue)
                    .font(.title2.weight(.semibold))
                Text(categoryType.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let cat = category, cat.totalSize > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(ByteFormatter.format(cat.totalSize))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(categoryType.color)
                    Text("\(cat.files.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("All Clean!")
                .font(.headline)
            Text("No files found in this category")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await scannerVM.scanCategory(categoryType) }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private func fileListView(category: CleanCategory) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                let selectedCount = category.files.filter(\.isSelected).count
                Button {
                    let allSelected = selectedCount == category.files.count
                    scannerVM.selectAllFiles(categoryType: categoryType, selected: !allSelected)
                } label: {
                    Text(selectedCount == category.files.count ? "Deselect All" : "Select All")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if selectedCount > 0 {
                    Text("\(selectedCount) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await scannerVM.scanCategory(categoryType) }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    let selectedFiles = category.files.filter(\.isSelected)
                    if selectedFiles.isEmpty {
                        cleanerVM.requestClean(action: .category(category))
                    } else {
                        cleanerVM.requestClean(action: .selectedFiles(selectedFiles))
                    }
                } label: {
                    let selectedFiles = category.files.filter(\.isSelected)
                    if selectedFiles.isEmpty {
                        Label("Clean All", systemImage: "trash")
                    } else {
                        Label("Delete Selected", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .disabled(cleanerVM.isCleaning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // File list
            List {
                ForEach(category.files) { file in
                    FileRow(
                        file: file,
                        isSelected: file.isSelected,
                        onToggle: {
                            scannerVM.toggleFileSelection(categoryType: categoryType, fileID: file.id)
                        }
                    )
                }
            }
            .listStyle(.inset)
        }
    }
}

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: file.isDirectory ? "folder.fill" : fileIcon)
                .foregroundStyle(file.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormatter.format(file.size))
                    .font(.callout.weight(.medium))
                Text(file.modifiedDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }

    private var fileIcon: String {
        switch file.fileExtension {
        case "zip", "gz", "tar", "rar", "7z": return "doc.zipper"
        case "dmg", "iso": return "opticaldisc"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "pdf": return "doc.richtext"
        case "log", "txt": return "doc.text"
        default: return "doc"
        }
    }
}
