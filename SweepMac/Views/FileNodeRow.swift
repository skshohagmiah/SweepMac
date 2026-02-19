import SwiftUI

struct FileNodeRow: View {
    let node: FileNode
    @ObservedObject var scannerVM: DiskScannerVM
    let categoryType: CleanCategoryType

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                    .frame(width: CGFloat(node.depth) * 20)

                if node.isDirectory {
                    Button {
                        Task {
                            if node.isExpanded {
                                scannerVM.collapseNode(node)
                            } else {
                                await scannerVM.expandNode(node)
                            }
                        }
                    } label: {
                        if node.isLoadingChildren {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                                .animation(.easeInOut(duration: 0.15), value: node.isExpanded)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 16)
                }

                Toggle("", isOn: Binding(
                    get: { node.isSelected },
                    set: { _ in scannerVM.toggleNodeSelection(node) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Image(systemName: node.isDirectory ? "folder.fill" : fileIcon(for: node.fileItem))
                    .foregroundStyle(node.isDirectory ? .blue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if node.depth == 0 {
                        Text(node.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormatter.format(node.size))
                        .font(.callout.weight(.medium))
                    Text(node.modifiedDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Show in Finder")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(node.isSelected ? Color.accentColor.opacity(0.08) : Color.clear)

            if node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(
                        node: child,
                        scannerVM: scannerVM,
                        categoryType: categoryType
                    )
                }
            }

            Divider()
                .padding(.leading, CGFloat(node.depth) * 20 + 20)
        }
    }

    private func fileIcon(for file: FileItem) -> String {
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
