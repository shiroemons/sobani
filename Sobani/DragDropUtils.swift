import Cocoa

enum DragDropUtils {
    static func extractImageURLs(from draggingInfo: NSDraggingInfo) -> [URL] {
        guard let items = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return [] }
        return items.filter { isSupportedImageURL($0) }
    }

    static func isSupportedImageURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ImageManager.supportedExtensions.contains(ext)
    }
}
