import Cocoa

// MARK: - NSServices Provider

extension AppDelegate {
    struct ServiceURLResult {
        let imageURLs: [URL]?
        let errorMessage: String?
    }

    /// サービス経由で受け取った URL 配列から対応画像を抽出する
    nonisolated static func extractImageURLsFromService(
        _ urls: [URL]?
    ) -> ServiceURLResult {
        guard let urls = urls else {
            return ServiceURLResult(imageURLs: nil, errorMessage: "No file URLs found")
        }
        let imageURLs = DragDropUtils.filterSupportedImages(urls)
        guard !imageURLs.isEmpty else {
            return ServiceURLResult(imageURLs: nil, errorMessage: "No supported image files")
        }
        return ServiceURLResult(imageURLs: imageURLs, errorMessage: nil)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.registerServicesMenuSendTypes([.fileURL], returnTypes: [])
        NSApp.servicesProvider = self
    }

    // swiftlint:disable legacy_objc_type
    @objc func openImageInSobani(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]

        let result = Self.extractImageURLsFromService(urls)
        if let imageURLs = result.imageURLs {
            NSApp.activate(ignoringOtherApps: true)
            for url in imageURLs {
                if let savedName = ImageManager.shared.registerImage(from: url) {
                    createNewWindow(imageName: savedName)
                }
            }
        } else if let message = result.errorMessage {
            error.pointee = message as NSString
        }
    }
    // swiftlint:enable legacy_objc_type
}
