import Cocoa
import Testing
@testable import Sobani

@Suite("ImageWindow Static Methods Tests")
struct ImageWindowTests {

    // MARK: - imageOrigin Tests

    @Test("画像原点の基本計算")
    func imageOriginBasic() {
        let windowFrame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let imageSize = NSSize(width: 200, height: 200)
        let result = ImageWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 100) < AppConstants.floatingPointTolerance)
    }

    @Test("画像がウィンドウより小さい場合の中心計算")
    func imageOriginSmallerImage() {
        let windowFrame = NSRect(x: 100, y: 100, width: 300, height: 300)
        let imageSize = NSSize(width: 200, height: 200)
        let result = ImageWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 150) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 150) < AppConstants.floatingPointTolerance)
    }

    @Test("非正方形ウィンドウでの計算")
    func imageOriginNonSquare() {
        let windowFrame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let imageSize = NSSize(width: 300, height: 150)
        let result = ImageWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 25) < AppConstants.floatingPointTolerance)
    }

    // MARK: - windowOrigin Tests

    @Test("ウィンドウ原点の基本計算（回転なし）")
    func windowOriginNoRotation() {
        let imageOrigin = CGPoint(x: 100, y: 100)
        let imageSize = NSSize(width: 200, height: 200)
        let result = ImageWindow.windowOrigin(
            forImageOrigin: imageOrigin, imageViewSize: imageSize, rotationAngle: 0
        )
        #expect(abs(result.x - 100) < 1.0)
        #expect(abs(result.y - 100) < 1.0)
    }

    @Test("回転時にウィンドウ原点がオフセット")
    func windowOriginWithRotation() {
        let imageOrigin = CGPoint(x: 100, y: 100)
        let imageSize = NSSize(width: 200, height: 100)
        let resultNoRotation = ImageWindow.windowOrigin(
            forImageOrigin: imageOrigin, imageViewSize: imageSize, rotationAngle: 0
        )
        let resultRotated = ImageWindow.windowOrigin(
            forImageOrigin: imageOrigin, imageViewSize: imageSize, rotationAngle: 45
        )
        #expect(resultRotated.x < resultNoRotation.x)
        #expect(resultRotated.y < resultNoRotation.y)
    }

    // MARK: - Round-trip Tests

    @Test("imageOrigin → windowOrigin のラウンドトリップ（回転なし）")
    func roundTripNoRotation() {
        let originalWindowFrame = NSRect(x: 150, y: 250, width: 200, height: 200)
        let imageSize = NSSize(width: 200, height: 200)
        let imgOrigin = ImageWindow.imageOrigin(
            windowFrame: originalWindowFrame, imageViewSize: imageSize
        )
        let recoveredWindowOrigin = ImageWindow.windowOrigin(
            forImageOrigin: imgOrigin, imageViewSize: imageSize, rotationAngle: 0
        )
        #expect(abs(recoveredWindowOrigin.x - originalWindowFrame.origin.x) <= 1.0)
        #expect(abs(recoveredWindowOrigin.y - originalWindowFrame.origin.y) <= 1.0)
    }

    @Test("imageOrigin → windowOrigin のラウンドトリップ（回転あり）")
    func roundTripWithRotation() {
        let imageSize = NSSize(width: 200, height: 100)
        let rotationAngle: CGFloat = 30
        let bbSize = GeometryUtils.rotatedBoundingBox(
            width: imageSize.width, height: imageSize.height, angleDegrees: rotationAngle
        )
        let originalWindowFrame = NSRect(x: 150, y: 250, width: bbSize.width, height: bbSize.height)
        let imgOrigin = ImageWindow.imageOrigin(
            windowFrame: originalWindowFrame, imageViewSize: imageSize
        )
        let recoveredWindowOrigin = ImageWindow.windowOrigin(
            forImageOrigin: imgOrigin, imageViewSize: imageSize, rotationAngle: rotationAngle
        )
        #expect(abs(recoveredWindowOrigin.x - originalWindowFrame.origin.x) <= 1.0)
        #expect(abs(recoveredWindowOrigin.y - originalWindowFrame.origin.y) <= 1.0)
    }

    // MARK: - calculateWindowSize Tests

    @Test("画像がmaxHeight以下の場合はスケールアップされる")
    func calculateWindowSizeBelowMax() {
        let imageSize = NSSize(width: 200, height: 300)
        let maxHeight: CGFloat = 600
        let result = ImageWindow.calculateWindowSize(imageSize: imageSize, maxHeight: maxHeight)
        #expect(abs(result.height - 600) < AppConstants.floatingPointTolerance)
        // アスペクト比維持: 200/300 * 600 = 400
        #expect(abs(result.width - 400) < AppConstants.floatingPointTolerance)
    }

    @Test("画像がmaxHeight超過の場合はmaxHeightに縮小される")
    func calculateWindowSizeAboveMax() {
        let imageSize = NSSize(width: 400, height: 1200)
        let maxHeight: CGFloat = 600
        let result = ImageWindow.calculateWindowSize(imageSize: imageSize, maxHeight: maxHeight)
        #expect(abs(result.height - 600) < AppConstants.floatingPointTolerance)
        // アスペクト比維持: 400/1200 * 600 = 200
        #expect(abs(result.width - 200) < AppConstants.floatingPointTolerance)
    }

    @Test("正方形画像のウィンドウサイズ計算")
    func calculateWindowSizeSquare() {
        let imageSize = NSSize(width: 500, height: 500)
        let maxHeight: CGFloat = 600
        let result = ImageWindow.calculateWindowSize(imageSize: imageSize, maxHeight: maxHeight)
        #expect(abs(result.height - 600) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 600) < AppConstants.floatingPointTolerance)
    }

    @Test("横長画像のウィンドウサイズ計算")
    func calculateWindowSizeLandscape() {
        let imageSize = NSSize(width: 1000, height: 500)
        let maxHeight: CGFloat = 600
        let result = ImageWindow.calculateWindowSize(imageSize: imageSize, maxHeight: maxHeight)
        #expect(abs(result.height - 600) < AppConstants.floatingPointTolerance)
        // アスペクト比維持: 1000/500 * 600 = 1200
        #expect(abs(result.width - 1200) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculateImageDimensions Tests

    @Test("正方形画像のアスペクト比")
    func calculateImageDimensionsSquare() {
        let result = ImageWindow.calculateImageDimensions(
            baseHeight: 600, imageSize: NSSize(width: 500, height: 500)
        )
        #expect(abs(result.aspectRatio - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 600) < AppConstants.floatingPointTolerance)
    }

    @Test("横長画像の幅計算")
    func calculateImageDimensionsLandscape() {
        let result = ImageWindow.calculateImageDimensions(
            baseHeight: 300, imageSize: NSSize(width: 800, height: 400)
        )
        // scale = 300/400 = 0.75, width = 800 * 0.75 = 600
        #expect(abs(result.width - 600) < AppConstants.floatingPointTolerance)
        #expect(abs(result.aspectRatio - 2.0) < AppConstants.floatingPointTolerance)
    }

    @Test("縦長画像の幅計算")
    func calculateImageDimensionsPortrait() {
        let result = ImageWindow.calculateImageDimensions(
            baseHeight: 600, imageSize: NSSize(width: 200, height: 800)
        )
        // scale = 600/800 = 0.75, width = 200 * 0.75 = 150
        #expect(abs(result.width - 150) < AppConstants.floatingPointTolerance)
        #expect(abs(result.aspectRatio - 0.25) < AppConstants.floatingPointTolerance)
    }

    // MARK: - formatLocalizedDisplayName Tests

    @Test("デフォルト名と一致する場合はローカライズ名を返す")
    func formatLocalizedDisplayNameDefault() {
        let result = ImageWindow.formatLocalizedDisplayName(
            displayName: "default", defaultName: "default", localizedDefault: "デフォルト"
        )
        #expect(result == "デフォルト")
    }

    @Test("デフォルト名と不一致の場合はそのまま返す")
    func formatLocalizedDisplayNameCustom() {
        let result = ImageWindow.formatLocalizedDisplayName(
            displayName: "my_image", defaultName: "default", localizedDefault: "デフォルト"
        )
        #expect(result == "my_image")
    }

    @Test("空文字列の場合はそのまま返す")
    func formatLocalizedDisplayNameEmpty() {
        let result = ImageWindow.formatLocalizedDisplayName(
            displayName: "", defaultName: "default", localizedDefault: "デフォルト"
        )
        #expect(result == "")
    }

    // MARK: - isAlphaInfoTransparent Tests

    @Test("premultipliedLast は透明")
    func isAlphaInfoTransparentPremultipliedLast() {
        #expect(ImageWindow.isAlphaInfoTransparent(.premultipliedLast) == true)
    }

    @Test("premultipliedFirst は透明")
    func isAlphaInfoTransparentPremultipliedFirst() {
        #expect(ImageWindow.isAlphaInfoTransparent(.premultipliedFirst) == true)
    }

    @Test("first は透明")
    func isAlphaInfoTransparentFirst() {
        #expect(ImageWindow.isAlphaInfoTransparent(.first) == true)
    }

    @Test("last は透明")
    func isAlphaInfoTransparentLast() {
        #expect(ImageWindow.isAlphaInfoTransparent(.last) == true)
    }

    @Test("none は不透明")
    func isAlphaInfoTransparentNone() {
        #expect(ImageWindow.isAlphaInfoTransparent(.none) == false)
    }

    @Test("noneSkipLast は不透明")
    func isAlphaInfoTransparentNoneSkipLast() {
        #expect(ImageWindow.isAlphaInfoTransparent(.noneSkipLast) == false)
    }

    // MARK: - menuTitleLocalizationKey Tests

    @Test("有効なタグで対応するキーを返す")
    func menuTitleLocalizationKeyValid() {
        let result = ImageWindow.menuTitleLocalizationKey(forTag: MenuItemTag.quit.rawValue)
        #expect(result == "menu.quit")
    }

    @Test("無効なタグでnilを返す")
    func menuTitleLocalizationKeyInvalid() {
        let result = ImageWindow.menuTitleLocalizationKey(forTag: 9999)
        #expect(result == nil)
    }

    @Test("複数のタグで正しいキーが返る")
    func menuTitleLocalizationKeyMultiple() {
        let changeImageTag = MenuItemTag.changeImageSubmenu.rawValue
        #expect(ImageWindow.menuTitleLocalizationKey(forTag: changeImageTag) == "image.change")
        #expect(
            ImageWindow.menuTitleLocalizationKey(forTag: MenuItemTag.flipContext.rawValue)
                == "adjust.flip"
        )
        #expect(
            ImageWindow.menuTitleLocalizationKey(forTag: MenuItemTag.close.rawValue)
                == "menu.close_image"
        )
    }
}

@Suite("ImageWindow Notification Tests")
@MainActor
struct ImageWindowNotificationTests {
    private final class NotificationCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        func record(_ trigger: String?) {
            lock.withLock {
                value = trigger
            }
        }

        var trigger: String? {
            lock.withLock { value }
        }
    }

    @Test("サイズ変更時に状態変更通知が送られる")
    func sizeChangePostsStateNotification() {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let imageWindow = ImageWindow(image: image)
        defer { imageWindow.window.orderOut(nil) }

        let capture = NotificationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: AppConstants.imageWindowStateDidChange,
            object: nil,
            queue: nil
        ) { notification in
            capture.record(notification.userInfo?[AppConstants.notificationTriggerKey] as? String)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        imageWindow.imageView.onSizeChanged?()

        #expect(capture.trigger == AppConstants.SnapshotTrigger.size.rawValue)
    }
}
