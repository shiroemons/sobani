import Cocoa

// MARK: - Drag & Drop Setup

extension ManagementPanelWindowListView {
    func setupDragDrop() {
        listTableView?.registerForDraggedTypes([.string])
        listTableView?.draggingDestinationFeedbackStyle = .gap
    }
}

// MARK: - NSTableViewDataSource (Drag & Drop)

extension ManagementPanelWindowListView {
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: .string)
        return item
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: any NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard dropOperation == .above else { return [] }
        return .move
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: any NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let sourceRowStr = item.string(forType: .string),
              let sourceRow = Int(sourceRowStr) else { return false }
        guard sourceRow != row, sourceRow != row - 1 else { return false }
        guard sourceRow < windows.count else { return false }
        let charWindow = windows[sourceRow]
        let destRow = sourceRow < row ? row - 1 : row
        onReorder?(charWindow, destRow)
        return true
    }
}
