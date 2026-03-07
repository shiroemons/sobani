import XCTest
@testable import Sobani

/// 回転バウンディングボックス計算と角度正規化の正確性を検証するテスト
final class GeometryUtilsTests: XCTestCase {

    // MARK: - rotatedBoundingBox Tests

    /// 0度回転でサイズが変わらないことを検証
    func testRotatedBoundingBox_ZeroDegrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 0)
        XCTAssertEqual(size.width, 100, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 50, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 90度回転で幅と高さが入れ替わることを検証
    func testRotatedBoundingBox_90Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 90)
        XCTAssertEqual(size.width, 50, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 100, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 180度回転でサイズが元に戻ることを検証
    func testRotatedBoundingBox_180Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 180)
        XCTAssertEqual(size.width, 100, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 50, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 270度回転で幅と高さが入れ替わることを検証
    func testRotatedBoundingBox_270Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 270)
        XCTAssertEqual(size.width, 50, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 100, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 正方形の45度回転で対角線長のバウンディングボックスになることを検証
    func testRotatedBoundingBox_45Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 100, angleDegrees: 45)
        // 正方形を45度回転: 対角線の長さ = 100 * sqrt(2) ≈ 141.42
        let expected = 100 * sqrt(2.0)
        XCTAssertEqual(size.width, expected, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, expected, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 非正方形の45度回転でバウンディングボックスが正しく計算されることを検証
    func testRotatedBoundingBox_45Degrees_NonSquare() {
        let size = GeometryUtils.rotatedBoundingBox(width: 200, height: 100, angleDegrees: 45)
        // 200x100を45°回転: |200*cos45°|+|100*sin45°| = 141.42+70.71 = 212.13
        XCTAssertEqual(size.width, 212.13, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 212.13, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 負の角度と正の角度で同じバウンディングボックスになることを検証
    func testRotatedBoundingBox_NegativeAngle() {
        let positive = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 30)
        let negative = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: -30)
        XCTAssertEqual(positive.width, negative.width, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(positive.height, negative.height, accuracy: AppConstants.floatingPointTolerance)
    }

    // MARK: - normalizeAngle Tests

    /// 0-359度の範囲内の角度がそのまま返されることを検証
    func testNormalizeAngle_AlreadyNormalized() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(45), 45, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(0), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(359), 359, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 負の角度が0-359度の範囲に正規化されることを検証
    func testNormalizeAngle_Negative() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(-90), 270, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-360), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-1), 359, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 360度以上の角度が0-359度の範囲に正規化されることを検証
    func testNormalizeAngle_Overflow() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(360), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(450), 90, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(720), 0, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 大きな負の角度が正しく正規化されることを検証
    func testNormalizeAngle_LargeNegative() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(-720), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-270), 90, accuracy: AppConstants.floatingPointTolerance)
    }
}
