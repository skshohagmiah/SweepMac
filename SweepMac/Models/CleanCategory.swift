import Foundation
import SwiftUI

enum CleanCategoryType: String, CaseIterable, Identifiable, Codable {
    case systemCaches = "System Caches"
    case applicationLogs = "Application Logs"
    case trash = "Trash"
    case systemData = "System Data"
    case xcode = "Xcode"
    case iosBackups = "iOS Backups"
    case docker = "Docker"
    case nodeModules = "node_modules"
    case homebrewCache = "Homebrew Cache"
    case mailAttachments = "Mail Attachments"
    case largeFiles = "Large Files"
    case downloads = "Downloads"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCaches: return "internaldrive"
        case .applicationLogs: return "doc.text"
        case .trash: return "trash"
        case .systemData: return "opticaldiscdrive"
        case .xcode: return "hammer"
        case .iosBackups: return "iphone"
        case .docker: return "shippingbox"
        case .nodeModules: return "shippingbox.fill"
        case .homebrewCache: return "mug"
        case .mailAttachments: return "paperclip"
        case .largeFiles: return "doc.zipper"
        case .downloads: return "arrow.down.circle"
        }
    }

    var color: Color {
        switch self {
        case .systemCaches: return .blue
        case .applicationLogs: return .orange
        case .trash: return .red
        case .systemData: return Color(red: 0.45, green: 0.45, blue: 0.95)
        case .xcode: return .indigo
        case .iosBackups: return .cyan
        case .docker: return .teal
        case .nodeModules: return .green
        case .homebrewCache: return .brown
        case .mailAttachments: return .purple
        case .largeFiles: return .pink
        case .downloads: return .mint
        }
    }

    var safeToClean: Bool {
        switch self {
        case .systemCaches, .applicationLogs, .trash, .homebrewCache, .nodeModules:
            return true
        case .xcode, .iosBackups, .docker:
            return true
        case .systemData, .mailAttachments, .largeFiles, .downloads:
            return false // manual review
        }
    }

    var description: String {
        switch self {
        case .systemCaches: return "Browser and app caches"
        case .applicationLogs: return "System and app log files"
        case .trash: return "Files in your Trash"
        case .systemData: return "App data, containers, and support files"
        case .xcode: return "DerivedData, simulators, archives"
        case .iosBackups: return "Old iOS device backups"
        case .docker: return "Docker images and containers"
        case .nodeModules: return "Node.js dependency folders"
        case .homebrewCache: return "Homebrew download cache"
        case .mailAttachments: return "Downloaded mail attachments"
        case .largeFiles: return "Files larger than 500 MB"
        case .downloads: return "Old files in Downloads folder"
        }
    }

    var scanPaths: [String] {
        let home = NSHomeDirectory()
        switch self {
        case .systemCaches:
            return [
                "\(home)/Library/Caches"
            ]
        case .applicationLogs:
            return [
                "\(home)/Library/Logs"
            ]
        case .trash:
            return ["\(home)/.Trash"]
        case .systemData:
            return [] // Handled specially in DiskScanner
        case .xcode:
            return [
                "\(home)/Library/Developer/Xcode/DerivedData",
                "\(home)/Library/Developer/Xcode/Archives",
                "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
                "\(home)/Library/Developer/CoreSimulator/Devices"
            ]
        case .iosBackups:
            return ["\(home)/Library/Application Support/MobileSync/Backup"]
        case .docker:
            return [
                "\(home)/Library/Containers/com.docker.docker",
                "\(home)/.docker"
            ]
        case .nodeModules:
            return [
                "\(home)/Projects",
                "\(home)/Developer",
                "\(home)/Documents",
                "\(home)/Desktop"
            ]
        case .homebrewCache:
            return ["\(home)/Library/Caches/Homebrew"]
        case .mailAttachments:
            return ["\(home)/Library/Mail"]
        case .largeFiles:
            return [home]
        case .downloads:
            return ["\(home)/Downloads"]
        }
    }
}

struct CleanCategory: Identifiable {
    let id = UUID()
    let type: CleanCategoryType
    var totalSize: Int64 = 0
    var files: [FileItem] = []
    var isScanning: Bool = false
    var isSelected: Bool = true

    var name: String { type.rawValue }
    var icon: String { type.icon }
    var color: Color { type.color }
    var safeToClean: Bool { type.safeToClean }
}
