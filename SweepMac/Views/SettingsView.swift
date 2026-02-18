import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsVM: SettingsVM

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Cleaning Behavior
                settingsSection("Cleaning Behavior") {
                    Toggle("Move files to Trash (recoverable)", isOn: $settingsVM.moveToTrash)
                    Text(settingsVM.moveToTrash
                         ? "Files are moved to Trash and can be recovered."
                         : "Warning: Files will be permanently deleted!")
                        .font(.caption)
                        .foregroundStyle(settingsVM.moveToTrash ? Color.secondary : Color.red)
                }

                // Thresholds
                settingsSection("Thresholds") {
                    HStack {
                        Text("Old file threshold (Downloads)")
                        Spacer()
                        Picker("", selection: $settingsVM.oldFileThresholdDays) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                            Text("60 days").tag(60)
                            Text("90 days").tag(90)
                        }
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Large file threshold")
                        Spacer()
                        Picker("", selection: $settingsVM.largeFileThresholdMB) {
                            Text("100 MB").tag(100)
                            Text("250 MB").tag(250)
                            Text("500 MB").tag(500)
                            Text("1 GB").tag(1024)
                        }
                        .frame(width: 120)
                    }
                }

                // Categories
                settingsSection("Scan Categories") {
                    ForEach(CleanCategoryType.allCases) { type in
                        Toggle(isOn: Binding(
                            get: { settingsVM.isCategoryEnabled(type) },
                            set: { _ in settingsVM.toggleCategory(type) }
                        )) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                    .frame(width: 24)
                                Text(type.rawValue)
                            }
                        }
                    }
                }

                // General
                settingsSection("General") {
                    Toggle("Show scan reminder notifications", isOn: $settingsVM.showNotifications)
                }

                // About
                settingsSection("About") {
                    HStack {
                        Text("SweepMac")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Version 1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("License")
                        Spacer()
                        Text("MIT")
                            .foregroundStyle(.secondary)
                    }

                    Button("Check for Full Disk Access") {
                        let hasAccess = PermissionChecker.hasFullDiskAccess()
                        // In a real app, show an alert with the result
                        NSLog("Full Disk Access: \(hasAccess)")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
