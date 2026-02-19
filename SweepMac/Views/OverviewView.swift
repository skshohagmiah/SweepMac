import SwiftUI
import Charts

struct OverviewView: View {
    @ObservedObject var scannerVM: DiskScannerVM
    @ObservedObject var cleanerVM: CleanerVM
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(white: 0.13)
            : Color.white
    }

    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(white: 0.08)
            : Color(white: 0.94)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                diskUsageCard
                storageBreakdownCard
                actionBar
                trendsCard
                categorySection
            }
            .padding(24)
        }
        .background(pageBackground)
    }

    // MARK: - Disk Usage Hero Card

    private var diskUsageCard: some View {
        HStack(spacing: 28) {
            DiskChartView(diskInfo: scannerVM.diskInfo)
                .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Macintosh HD")
                        .font(.title3.weight(.semibold))
                    Text(scannerVM.diskInfo.totalSpace > 0
                         ? "\(ByteFormatter.format(scannerVM.diskInfo.freeSpace)) available of \(ByteFormatter.format(scannerVM.diskInfo.totalSpace))"
                         : "Scanning...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 20) {
                    statPill(label: "Used", value: ByteFormatter.shortFormat(scannerVM.diskInfo.usedSpace), color: usageColor)
                    statPill(label: "Free", value: ByteFormatter.shortFormat(scannerVM.diskInfo.freeSpace), color: .green)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last scan: \(scannerVM.lastScanFormatted)")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(24)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 2)
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Storage Breakdown Bar

    private var storageBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Storage Breakdown")
                    .font(.headline)
                Spacer()
                if scannerVM.isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Found \(ByteFormatter.format(scannerVM.totalCleanableSize)) to clean")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                        .fontWeight(.medium)
                }
            }

            // Stacked bar
            GeometryReader { geo in
                let total = max(scannerVM.diskInfo.totalSpace, 1)
                HStack(spacing: 1.5) {
                    ForEach(scannerVM.categories.filter { $0.totalSize > 0 }) { cat in
                        let fraction = CGFloat(cat.totalSize) / CGFloat(total)
                        let width = max(fraction * geo.size.width, 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cat.color.gradient)
                            .frame(width: width)
                            .help("\(cat.name): \(ByteFormatter.format(cat.totalSize))")
                    }

                    // Remaining used (system/other)
                    let scannedTotal = scannerVM.categories.reduce(Int64(0)) { $0 + $1.totalSize }
                    let otherUsed = max(scannerVM.diskInfo.usedSpace - min(scannedTotal, scannerVM.diskInfo.usedSpace), 0)
                    if otherUsed > 0 {
                        let fraction = CGFloat(otherUsed) / CGFloat(total)
                        let width = max(fraction * geo.size.width, 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.4).gradient)
                            .frame(width: width)
                            .help("Other: \(ByteFormatter.format(otherUsed))")
                    }

                    // Free space
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.15))
                        .help("Free: \(ByteFormatter.format(scannerVM.diskInfo.freeSpace))")
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Legend
            let visibleCategories = scannerVM.categories.filter { $0.totalSize > 0 }.prefix(6)
            FlowLayout(spacing: 8) {
                ForEach(Array(visibleCategories)) { cat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cat.color)
                            .frame(width: 7, height: 7)
                        Text("\(cat.name)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(ByteFormatter.shortFormat(cat.totalSize))
                            .font(.caption2.weight(.medium))
                    }
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text("Free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(ByteFormatter.shortFormat(scannerVM.diskInfo.freeSpace))
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 2)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await scannerVM.scanAll() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Scan All")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(scannerVM.isScanning)

            Button {
                let safeCategories = scannerVM.categories.filter { $0.safeToClean && $0.totalSize > 0 }
                cleanerVM.requestClean(action: .allCategories(safeCategories))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Clean All Safe")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .controlSize(.large)
            .disabled(scannerVM.totalCleanableSize == 0 || cleanerVM.isCleaning)

            if scannerVM.isScanning {
                ProgressView(value: scannerVM.scanProgress)
                    .frame(width: 80)
                    .tint(.indigo)
            }
        }
    }

    // MARK: - Category Grid

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categories")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200), spacing: 14)
            ], spacing: 14) {
                ForEach(scannerVM.categories) { category in
                    CategoryCard(
                        category: category,
                        cardBackground: cardBackground,
                        isDark: colorScheme == .dark
                    ) {
                        cleanerVM.requestClean(action: .category(category))
                    }
                }
            }
        }
    }

    // MARK: - Cleanup Trends

    @ViewBuilder
    private var trendsCard: some View {
        let snapshots = ScanSnapshot.loadAll()
        if snapshots.count >= 2 {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Cleanup Trends")
                        .font(.headline)
                    Spacer()
                    Text("\(snapshots.count) scans")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Chart(snapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Cleanable", snapshot.totalCleanableSize)
                    )
                    .foregroundStyle(Color.indigo.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Cleanable", snapshot.totalCleanableSize)
                    )
                    .foregroundStyle(Color.indigo.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Cleanable", snapshot.totalCleanableSize)
                    )
                    .foregroundStyle(Color.indigo)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteFormatter.shortFormat(bytes))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
            .padding(20)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, y: 2)
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

// MARK: - Category Card

struct CategoryCard: View {
    let category: CleanCategory
    let cardBackground: Color
    let isDark: Bool
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(category.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(category.type.description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if category.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 40)
            } else {
                HStack(alignment: .bottom) {
                    Text(ByteFormatter.format(category.totalSize))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(category.totalSize > 0 ? .primary : .quaternary)

                    Spacer()

                    if !category.safeToClean && category.totalSize > 0 {
                        Text("Review")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.color.gradient)
                            .frame(width: max(geo.size.width * progressValue, 2))
                    }
                }
                .frame(height: 5)
            }

            if category.totalSize > 0 && !category.isScanning {
                Button(action: onClean) {
                    Text(category.safeToClean ? "Clean" : "Inspect")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                }
                .buttonStyle(.bordered)
                .tint(category.safeToClean ? category.color : .orange)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(minHeight: 150)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(isDark ? 0.25 : 0.05), radius: 6, y: 2)
    }

    private var progressValue: Double {
        guard category.totalSize > 0 else { return 0 }
        let maxDisplay: Int64 = 10 * 1024 * 1024 * 1024
        return min(Double(category.totalSize) / Double(maxDisplay), 1.0)
    }
}

// MARK: - Flow Layout for Legend

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
