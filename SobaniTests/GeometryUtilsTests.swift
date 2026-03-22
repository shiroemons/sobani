import CoreGraphics
import Testing
@testable import Sobani

/// 回転バウンディングボックス計算と角度正規化の正確性を検証するテスト
@Suite @MainActor struct GeometryUtilsTests {

    // MARK: - rotatedBoundingBox Parameterized Tests

    /// 基本角度(0, 90, 180, 270度)でバウンディングボックスが正しいことを検証
    @Test(arguments: [
        (0.0, 100.0, 50.0, 100.0, 50.0),
        (90.0, 100.0, 50.0, 50.0, 100.0),
        (180.0, 100.0, 50.0, 100.0, 50.0),
        (270.0, 100.0, 50.0, 50.0, 100.0),
    ])
    func rotatedBoundingBox_BasicAngles(
        angle: Double, width: Double, height: Double, expectedWidth: Double, expectedHeight: Double
    ) {
        let size = GeometryUtils.rotatedBoundingBox(
            width: CGFloat(width), height: CGFloat(height), angleDegrees: CGFloat(angle)
        )
        #expect(abs(size.width - CGFloat(expectedWidth)) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - CGFloat(expectedHeight)) < AppConstants.floatingPointTolerance)
    }

    /// 正方形の45度回転で対角線長のバウンディングボックスになることを検証
    @Test func rotatedBoundingBox_45Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 100, angleDegrees: 45)
        let expected = 100 * sqrt(2.0)
        #expect(abs(size.width - expected) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - expected) < AppConstants.floatingPointTolerance)
    }

    /// 非正方形の45度回転でバウンディングボックスが正しく計算されることを検証
    @Test func rotatedBoundingBox_45Degrees_NonSquare() {
        let size = GeometryUtils.rotatedBoundingBox(width: 200, height: 100, angleDegrees: 45)
        #expect(abs(size.width - 212.13) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - 212.13) < AppConstants.floatingPointTolerance)
    }

    /// 負の角度と正の角度で同じバウンディングボックスになることを検証
    @Test func rotatedBoundingBox_NegativeAngle() {
        let positive = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 30)
        let negative = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: -30)
        #expect(abs(positive.width - negative.width) < AppConstants.floatingPointTolerance)
        #expect(abs(positive.height - negative.height) < AppConstants.floatingPointTolerance)
    }

    // MARK: - normalizeAngle Parameterized Tests

    /// 各種角度が正しく0-359度の範囲に正規化されることを検証
    @Test(arguments: [
        (0.0, 0.0), (45.0, 45.0), (359.0, 359.0),
        (-90.0, 270.0), (-360.0, 0.0), (-1.0, 359.0),
        (360.0, 0.0), (450.0, 90.0), (720.0, 0.0),
        (-720.0, 0.0), (-270.0, 90.0),
    ])
    func normalizeAngle_MultipleAngles(input: Double, expected: Double) {
        #expect(
            abs(GeometryUtils.normalizeAngle(CGFloat(input)) - CGFloat(expected))
                < AppConstants.floatingPointTolerance
        )
    }

    // MARK: - isApproximatelyZero Tests

    @Test func isApproximatelyZero_ExactlyZero() {
        #expect(GeometryUtils.isApproximatelyZero(0.0))
    }

    @Test func isApproximatelyZero_WithinTolerance() {
        #expect(GeometryUtils.isApproximatelyZero(0.005))
        #expect(GeometryUtils.isApproximatelyZero(-0.005))
    }

    @Test func isApproximatelyZero_AtToleranceBoundary() {
        #expect(!GeometryUtils.isApproximatelyZero(AppConstants.floatingPointTolerance))
        #expect(!GeometryUtils.isApproximatelyZero(-AppConstants.floatingPointTolerance))
    }

    @Test func isApproximatelyZero_BeyondTolerance() {
        #expect(!GeometryUtils.isApproximatelyZero(0.1))
        #expect(!GeometryUtils.isApproximatelyZero(-0.1))
    }

    // MARK: - isApproximatelyEqual Tests

    @Test func isApproximatelyEqual_SameValues() {
        #expect(GeometryUtils.isApproximatelyEqual(1.0, 1.0))
        #expect(GeometryUtils.isApproximatelyEqual(0.0, 0.0))
        #expect(GeometryUtils.isApproximatelyEqual(-5.0, -5.0))
    }

    @Test func isApproximatelyEqual_WithinTolerance() {
        #expect(GeometryUtils.isApproximatelyEqual(1.0, 1.005))
        #expect(GeometryUtils.isApproximatelyEqual(1.005, 1.0))
    }

    @Test func isApproximatelyEqual_AtToleranceBoundary() {
        #expect(!GeometryUtils.isApproximatelyEqual(0.0, AppConstants.floatingPointTolerance))
        #expect(!GeometryUtils.isApproximatelyEqual(AppConstants.floatingPointTolerance, 0.0))
    }

    @Test func isApproximatelyEqual_BeyondTolerance() {
        #expect(!GeometryUtils.isApproximatelyEqual(1.0, 1.1))
        #expect(!GeometryUtils.isApproximatelyEqual(1.0, 2.0))
    }
}
