import Cocoa
import os.log

// MARK: - NSServices Provider

private let servicesLogger = Logger(category: "AppDelegate+Services")

extension AppDelegate {
    struct ServiceURLResult {
        let imageURLs: [URL]?
        let errorMessage: String?
        /// 上限（`AppConstants.maxServiceImageCount`）を超えたため開かない画像の数
        var skippedCount = 0
    }

    /// サービス経由で受け取った URL 配列から対応画像を抽出する（上限を超えた分は除外する）
    nonisolated static func extractImageURLsFromService(
        _ urls: [URL]?,
        maxCount: Int = AppConstants.maxServiceImageCount
    ) -> ServiceURLResult {
        guard let urls = urls else {
            return ServiceURLResult(imageURLs: nil, errorMessage: L("service.error.no_file_urls"))
        }
        let imageURLs = DragDropUtils.filterSupportedImages(urls)
        guard !imageURLs.isEmpty else {
            return ServiceURLResult(imageURLs: nil, errorMessage: L("service.error.no_supported_images"))
        }
        let accepted = Array(imageURLs.prefix(maxCount))
        return ServiceURLResult(
            imageURLs: accepted, errorMessage: nil, skippedCount: imageURLs.count - accepted.count
        )
    }

    /// サービスは Info.plist の `NSServices` で宣言し、`servicesProvider` で受け取る。
    /// （`registerServicesMenuSendTypes` はサービスを「利用する」側の宣言のため、提供側では不要）
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningUnitTests else { return }
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
        guard let imageURLs = result.imageURLs else {
            if let message = result.errorMessage {
                error.pointee = message as NSString
            }
            return
        }
        if result.skippedCount > 0 {
            servicesLogger.notice(
                "Service request exceeded the limit; skipped \(result.skippedCount, privacy: .public) images"
            )
        }
        NSApp.activate()
        let openedResults = imageURLs.map { createNewWindow(registeringImageAt: $0) }
        if !openedResults.contains(true) {
            error.pointee = L("service.error.registration_failed") as NSString
        }
    }
    // swiftlint:enable legacy_objc_type
}
