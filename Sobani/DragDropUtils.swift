import Cocoa

enum DragDropUtils {
    static func extractImageURLs(from draggingInfo: NSDraggingInfo) -> [URL] {
        // NSURL はドラッグ&ドロップ API に必要
        // swiftlint:disable legacy_objc_type
        guard let items = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return [] }
        // swiftlint:enable legacy_objc_type
        return filterSupportedImages(items)
    }

    static func filterSupportedImages(_ urls: [URL]) -> [URL] {
        urls.filter { isSupportedImageURL($0) }
    }

    static func isSupportedImageURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ImageManager.supportedExtensions.contains(ext)
    }
}
