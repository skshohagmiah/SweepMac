import SwiftUI

struct OnboardingView: View {
    @ObservedObject var scannerVM: DiskScannerVM

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo)

                Text("Full Disk Access Required")
                    .font(.title.weight(.bold))

                Text("SweepMac needs Full Disk Access to scan your system for cleanable files. Without it, some categories won't be accessible.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(number: 1, text: "Open System Settings")
                    instructionRow(number: 2, text: "Go to Privacy & Security → Full Disk Access")
                    instructionRow(number: 3, text: "Enable SweepMac in the list")
                    instructionRow(number: 4, text: "Restart SweepMac")
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 16) {
                    Button("Open System Settings") {
                        PermissionChecker.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.large)

                    Button("Continue Anyway") {
                        scannerVM.hasFullDiskAccess = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .padding(40)
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(Color.indigo, in: Circle())
                .foregroundStyle(.white)
            Text(text)
                .font(.body)
        }
    }
}
