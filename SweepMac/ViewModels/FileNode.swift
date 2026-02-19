import Foundation
import SwiftUI

@Observable
final class FileNode: Identifiable {
    let id: UUID
    let fileItem: FileItem

    weak var parent: FileNode?
    var children: [FileNode]?

    var isExpanded: Bool = false
    var isSelected: Bool = false
    var isLoadingChildren: Bool = false

    var size: Int64

    var path: String { fileItem.path }
    var name: String { fileItem.name }
    var isDirectory: Bool { fileItem.isDirectory }
    var modifiedDate: Date { fileItem.modifiedDate }

    var hasLoadedChildren: Bool { children != nil }
    var isExpandable: Bool { isDirectory }

    var depth: Int {
        var d = 0
        var node = parent
        while node != nil { d += 1; node = node?.parent }
        return d
    }

    init(fileItem: FileItem, parent: FileNode? = nil) {
        self.id = fileItem.id
        self.fileItem = fileItem
        self.parent = parent
        self.size = fileItem.size
    }
}
