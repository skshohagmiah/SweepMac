import SwiftUI

struct CleanConfirmSheet: View {
    @ObservedObject var cleanerVM: CleanerVM
    @ObservedObject var scannerVM: DiskScannerVM
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 400)
    }
}
