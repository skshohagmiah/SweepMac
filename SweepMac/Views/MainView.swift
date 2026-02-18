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
            Text(cleanerVM.lastResult?.message ?? "")
        }
        .overlay {
            if !scannerVM.hasFullDiskAccess {
                OnboardingView(scannerVM: scannerVM)
            }
        }
        .task {
            await scannerVM.scanAll()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSidebar) {
            Section("General") {
                Label("Overview", systemImage: "gauge.medium")
                    .tag(SidebarItem.overview)
            }

            Section("Categories") {
                ForEach(CleanCategoryType.allCases) { type in
                    let category = scannerVM.category(for: type)
                    HStack {
                        Label(type.rawValue, systemImage: type.icon)
                        Spacer()
                        if let cat = category, cat.isScanning {
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
            }

            Section {
                Label("Settings", systemImage: "gear")
                    .tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await scannerVM.scanAll() }
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(scannerVM.isScanning)
            }
        }
    }

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
