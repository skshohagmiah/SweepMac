import SwiftUI

struct MainView: View {
    @StateObject private var scannerVM = DiskScannerVM()
    @StateObject private var cleanerVM = CleanerVM()
    @StateObject private var settingsVM = SettingsVM()
    @State private var selectedSidebar: SidebarItem = .overview

    enum SidebarItem: Hashable {
        case overview
        case category(CleanCategoryType)
        case settings
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 560)
        .sheet(isPresented: $cleanerVM.showConfirmation) {
            CleanConfirmSheet(cleanerVM: cleanerVM, scannerVM: scannerVM)
        }
        .alert("Clean Complete", isPresented: $cleanerVM.showResult) {
            Button("OK") { cleanerVM.showResult = false }
        } message: {
            if let result = cleanerVM.lastResult {
                VStack {
                    Text(result.message)
                    if let breakdown = result.breakdownSummary {
                        Text(breakdown)
                            .font(.caption)
                    }
                }
            }
        }
        .overlay {
            if !scannerVM.hasFullDiskAccess {
                OnboardingView(scannerVM: scannerVM)
            }
        }
        .overlay(alignment: .bottom) {
            if cleanerVM.isCleaning {
                cleaningProgressOverlay
            }
        }
        .task {
            await scannerVM.scanAll()
        }
    }

    // MARK: - Cleaning Progress Overlay

    private var cleaningProgressOverlay: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Cleaning...")
                .font(.subheadline.weight(.medium))
            ProgressView(value: cleanerVM.cleanProgress)
                .frame(width: 120)
                .tint(.indigo)
            Text("\(Int(cleanerVM.cleanProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: cleanerVM.isCleaning)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSidebar) {
            Section("General") {
                Label("Overview", systemImage: "gauge.medium")
                    .tag(SidebarItem.overview)
            }

            Section {
                ForEach(CleanCategoryType.allCases) { type in
                    let category = scannerVM.category(for: type)
                    HStack {
                        Label(type.rawValue, systemImage: type.icon)
                        Spacer()
                        if let cat = category, cat.scanError != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if let cat = category, cat.isScanning {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else if let cat = category, cat.totalSize > 0 {
                            Text(ByteFormatter.shortFormat(cat.totalSize))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SidebarItem.category(type))
                }
            } header: {
                HStack {
                    Text("Categories")
                    Spacer()
                    diskWarningBadge
                }
            }

            Section {
                Label("Settings", systemImage: "gear")
                    .tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .safeAreaInset(edge: .bottom) {
            if scannerVM.totalCleanableSize > 0 && !scannerVM.isScanning {
                HStack {
                    Image(systemName: "arrow.3.trianglepath")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text("\(ByteFormatter.format(scannerVM.totalCleanableSize)) cleanable")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await scannerVM.scanAll() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(scannerVM.isScanning)
            }
        }
    }

    @ViewBuilder
    private var diskWarningBadge: some View {
        switch scannerVM.diskInfo.usageLevel {
        case .healthy:
            EmptyView()
        case .warning:
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
                .help("Disk usage above 75%")
        case .critical:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .help("Disk usage critical — above 90%")
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedSidebar {
        case .overview:
            OverviewView(scannerVM: scannerVM, cleanerVM: cleanerVM)
        case .category(let type):
            CategoryDetailView(
                categoryType: type,
                scannerVM: scannerVM,
                cleanerVM: cleanerVM
            )
        case .settings:
            SettingsView(settingsVM: settingsVM)
        }
    }
}
