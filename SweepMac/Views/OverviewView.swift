import SwiftUI
import Charts

struct OverviewView: View {
    @ObservedObject var scannerVM: DiskScannerVM
    @ObservedObject var cleanerVM: CleanerVM

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                diskUsageCard
                cleanSummaryCard
                categoryGrid
                actionButtons
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
    }

    private var diskUsageCard: some View {
        VStack(spacing: 16) {
            Text("Disk Usage")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 32) {
                DiskChartView(diskInfo: scannerVM.diskInfo)
                    .frame(width: 160, height: 160)

                VStack(alignment: .leading, spacing: 12) {
                    diskStatRow(
                        label: "Total",
                        value: ByteFormatter.format(scannerVM.diskInfo.totalSpace),
                        color: .secondary
                    )
                    diskStatRow(
                        label: "Used",
                        value: ByteFormatter.format(scannerVM.diskInfo.usedSpace),
                        color: usageColor
                    )
                    diskStatRow(
                        label: "Free",
                        value: ByteFormatter.format(scannerVM.diskInfo.freeSpace),
                        color: .green
                    )

                    Divider()

                    HStack {
                        Text("Last scan:")
                            .foregroundStyle(.secondary)
                        Text(scannerVM.lastScanFormatted)
                    }
                    .font(.caption)
                }

                Spacer()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var cleanSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cleanable Space")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(scannerVM.totalCleanableSize))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.indigo)
            }

            Spacer()

            if scannerVM.isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scannerVM.scanProgress)
                        .frame(width: 120)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 180), spacing: 16)
        ], spacing: 16) {
            ForEach(scannerVM.categories) { category in
                CategoryCard(category: category) {
                    cleanerVM.requestClean(action: .category(category))
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                Task { await scannerVM.scanAll() }
            } label: {
                Label("Scan All", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(scannerVM.isScanning)

            Button {
                let safeCategories = scannerVM.categories.filter { $0.safeToClean && $0.totalSize > 0 }
                cleanerVM.requestClean(action: .allCategories(safeCategories))
            } label: {
                Label("Clean All Safe", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(scannerVM.totalCleanableSize == 0 || cleanerVM.isCleaning)
        }
        .padding(.top, 8)
    }

    private func diskStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private var usageColor: Color {
        switch scannerVM.diskInfo.usageLevel {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct CategoryCard: View {
    let category: CleanCategory
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(category.color)
                    .frame(width: 32)

                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()
            }

            if category.isScanning {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(ByteFormatter.format(category.totalSize))
                    .font(.system(size: 20, weight: .bold))

                ProgressView(value: progressValue)
                    .tint(category.color)
            }

            if category.totalSize > 0 {
                Button("Clean", action: onClean)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressValue: Double {
        guard category.totalSize > 0 else { return 0 }
        // Scale relative to largest category or a reasonable max
        let maxDisplay: Int64 = 10 * 1024 * 1024 * 1024 // 10 GB
        return min(Double(category.totalSize) / Double(maxDisplay), 1.0)
    }
}
