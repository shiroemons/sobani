import Cocoa
import Testing
@testable import Sobani

@Suite("CharacterWindow Static Methods Tests")
struct CharacterWindowTests {

    // MARK: - imageOrigin Tests

    @Test("画像原点の基本計算")
    func imageOriginBasic() {
        let windowFrame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let imageSize = NSSize(width: 200, height: 200)
        let result = CharacterWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 100) < AppConstants.floatingPointTolerance)
    }

    @Test("画像がウィンドウより小さい場合の中心計算")
    func imageOriginSmallerImage() {
        let windowFrame = NSRect(x: 100, y: 100, width: 300, height: 300)
        let imageSize = NSSize(width: 200, height: 200)
        let result = CharacterWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 150) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 150) < AppConstants.floatingPointTolerance)
    }

    @Test("非正方形ウィンドウでの計算")
    func imageOriginNonSquare() {
        let windowFrame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let imageSize = NSSize(width: 300, height: 150)
        let result = CharacterWindow.imageOrigin(windowFrame: windowFrame, imageViewSize: imageSize)
        #expect(abs(result.x - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 25) < AppConstants.floatingPointTolerance)
    }

    // MARK: - windowOrigin Tests

    @Test("ウィンドウ原点の基本計算（回転なし）")
    func windowOriginNoRotation() {
        let imageOrigin = CGPoint(x: 100, y: 100)
        let imageSize = NSSize(width: 200, height: 200)
        let result = CharacterWindow.windowOrigin(
            forImageOrigin: imageOrigin, imageViewSize: imageSize, rotationAngle: 0
        )
        #expect(abs(result.x - 100) < 1.0)
        #expect(abs(result.y - 100) < 1.0)
    }

    @Test("回転時にウィンドウ原点がオフセット")
    func windowOriginWithRotation() {
        let imageOrigin = CGPoint(x: 100, y: 100)
        let imageSize = NSSize(width: 200, height: 100)
        let resultNoRotation = CharacterWindow.windowOrigin(
            forImageOrigin: imageOrigin, imageViewSize: imageSize, rotationAngle: 0
        )
        let resultRotated = CharacterWindow.windowOrigin(
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
        let imgOrigin = CharacterWindow.imageOrigin(windowFrame: originalWindowFrame, imageViewSize: imageSize)
        let recoveredWindowOrigin = CharacterWindow.windowOrigin(
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
        let imgOrigin = CharacterWindow.imageOrigin(windowFrame: originalWindowFrame, imageViewSize: imageSize)
        let recoveredWindowOrigin = CharacterWindow.windowOrigin(
            forImageOrigin: imgOrigin, imageViewSize: imageSize, rotationAngle: rotationAngle
        )
        #expect(abs(recoveredWindowOrigin.x - originalWindowFrame.origin.x) <= 1.0)
        #expect(abs(recoveredWindowOrigin.y - originalWindowFrame.origin.y) <= 1.0)
    }
}
