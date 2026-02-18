import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modifiedDate: Date
    let isDirectory: Bool
    var isSelected: Bool = false

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }

    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: modifiedDate, to: Date()).day ?? 0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
