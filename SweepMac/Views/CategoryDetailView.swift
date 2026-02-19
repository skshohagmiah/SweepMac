import SwiftUI

enum SortOption: String, CaseIterable {
    case size = "Size"
    case name = "Name"
    case dateModified = "Date"
}

struct CategoryDetailView: View {
    let categoryType: CleanCategoryType
    @ObservedObject var scannerVM: DiskScannerVM
    @ObservedObject var cleanerVM: CleanerVM
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .size
    @State private var sortAscending: Bool = false

    private var category: CleanCategory? {
        scannerVM.category(for: categoryType)
    }

    private var pageBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.94)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.13) : Color.white
    }

    private var filteredAndSortedNodes: [FileNode] {
        guard var nodes = scannerVM.fileNodes[categoryType] else { return [] }

        // Filter by search text
        if !searchText.isEmpty {
            nodes = nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        nodes.sort { a, b in
            let result: Bool
            switch sortOption {
            case .size:
                result = a.size > b.size
            case .name:
                result = a.name.localizedCompare(b.name) == .orderedAscending
            case .dateModified:
                result = a.modifiedDate > b.modifiedDate
            }
            return sortAscending ? !result : result
        }

        return nodes
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if let category = category {
                if category.isScanning {
                    scanningView
                } else if let error = category.scanError {
                    errorView(error)
                } else if category.files.isEmpty {
                    emptyView
                } else {
                    fileListView(category: category)
                }
            }
        }
        .background(pageBackground)
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(categoryType.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: categoryType.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(categoryType.color)
            }

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
        .background(cardBackground)
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

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Scan Error")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                Button {
                    Task { await scannerVM.scanCategory(categoryType) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    PermissionChecker.openFullDiskAccessSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
            }
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
                let selectedItems = scannerVM.selectedFileItems(for: categoryType)
                let selectedCount = selectedItems.count
                let nodes = scannerVM.fileNodes[categoryType] ?? []

                Button {
                    let allSelected = !nodes.isEmpty && nodes.allSatisfy(\.isSelected)
                    scannerVM.selectAllNodes(categoryType: categoryType, selected: !allSelected)
                } label: {
                    let allSelected = !nodes.isEmpty && nodes.allSatisfy(\.isSelected)
                    Text(allSelected ? "Deselect All" : "Select All")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if selectedCount > 0 {
                    Text("\(selectedCount) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sort picker
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button {
                    sortAscending.toggle()
                } label: {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(sortAscending ? "Ascending" : "Descending")

                Button {
                    Task { await scannerVM.scanCategory(categoryType) }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    if selectedItems.isEmpty {
                        cleanerVM.requestClean(action: .category(category))
                    } else {
                        cleanerVM.requestClean(action: .selectedFiles(selectedItems))
                    }
                } label: {
                    if selectedItems.isEmpty {
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

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.96))

            Divider()

            let nodes = filteredAndSortedNodes

            if nodes.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(nodes) { node in
                            FileNodeRow(
                                node: node,
                                scannerVM: scannerVM,
                                categoryType: categoryType
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
