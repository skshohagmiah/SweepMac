import SwiftUI

@main
struct SweepMacApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 620)
    }
}
