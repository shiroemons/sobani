import Cocoa

// MARK: - NSServices Provider

extension AppDelegate {
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
        guard let urls = pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            error.pointee = "No file URLs found" as NSString
            return
        }
        let imageURLs = DragDropUtils.filterSupportedImages(urls)
        guard !imageURLs.isEmpty else {
            error.pointee = "No supported image files" as NSString
            return
        }
        // swiftlint:enable legacy_objc_type

        NSApp.activate(ignoringOtherApps: true)

        for url in imageURLs {
            if let savedName = ImageManager.shared.registerImage(from: url) {
                createNewWindow(imageName: savedName)
            }
        }
    }
}
