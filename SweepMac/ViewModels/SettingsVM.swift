import Foundation
import SwiftUI

@MainActor
class SettingsVM: ObservableObject {
    @AppStorage("moveToTrash") var moveToTrash: Bool = true
    @AppStorage("oldFileThresholdDays") var oldFileThresholdDays: Int = 30
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("largeFileThresholdMB") var largeFileThresholdMB: Int = 500

    @Published var excludedCategories: Set<CleanCategoryType> = []

    private let excludedKey = "excludedCategories"

    init() {
        loadExcludedCategories()
    }

    func isCategoryEnabled(_ type: CleanCategoryType) -> Bool {
        !excludedCategories.contains(type)
    }

    func toggleCategory(_ type: CleanCategoryType) {
        if excludedCategories.contains(type) {
            excludedCategories.remove(type)
        } else {
            excludedCategories.insert(type)
        }
        saveExcludedCategories()
    }

    private func loadExcludedCategories() {
        if let data = UserDefaults.standard.data(forKey: excludedKey),
           let decoded = try? JSONDecoder().decode(Set<CleanCategoryType>.self, from: data) {
            excludedCategories = decoded
        }
    }

    private func saveExcludedCategories() {
        if let data = try? JSONEncoder().encode(excludedCategories) {
            UserDefaults.standard.set(data, forKey: excludedKey)
        }
    }
}
