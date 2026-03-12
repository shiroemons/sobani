import Cocoa

@MainActor
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

    nonisolated static func filterSupportedImages(_ urls: [URL]) -> [URL] {
        urls.filter { isSupportedImageURL($0) }
    }

    nonisolated static func isSupportedImageURL(_ url: URL) -> Bool {
        ImageManager.isSupportedExtension(url.pathExtension)
    }
}
