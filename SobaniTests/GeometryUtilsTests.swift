import XCTest
@testable import Sobani

final class GeometryUtilsTests: XCTestCase {

    // MARK: - rotatedBoundingBox Tests

    func testRotatedBoundingBox_ZeroDegrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 0)
        XCTAssertEqual(size.width, 100, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 50, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_90Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 90)
        XCTAssertEqual(size.width, 50, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 100, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_180Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 180)
        XCTAssertEqual(size.width, 100, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 50, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_270Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 270)
        XCTAssertEqual(size.width, 50, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 100, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_45Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 100, angleDegrees: 45)
        // 正方形を45度回転: 対角線の長さ = 100 * sqrt(2) ≈ 141.42
        let expected = 100 * sqrt(2.0)
        XCTAssertEqual(size.width, expected, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, expected, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_45Degrees_NonSquare() {
        let size = GeometryUtils.rotatedBoundingBox(width: 200, height: 100, angleDegrees: 45)
        // 200x100を45°回転: |200*cos45°|+|100*sin45°| = 141.42+70.71 = 212.13
        XCTAssertEqual(size.width, 212.13, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(size.height, 212.13, accuracy: AppConstants.floatingPointTolerance)
    }

    func testRotatedBoundingBox_NegativeAngle() {
        let positive = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 30)
        let negative = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: -30)
        XCTAssertEqual(positive.width, negative.width, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(positive.height, negative.height, accuracy: AppConstants.floatingPointTolerance)
    }

    // MARK: - normalizeAngle Tests

    func testNormalizeAngle_AlreadyNormalized() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(45), 45, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(0), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(359), 359, accuracy: AppConstants.floatingPointTolerance)
    }

    func testNormalizeAngle_Negative() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(-90), 270, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-360), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-1), 359, accuracy: AppConstants.floatingPointTolerance)
    }

    func testNormalizeAngle_Overflow() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(360), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(450), 90, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(720), 0, accuracy: AppConstants.floatingPointTolerance)
    }

    func testNormalizeAngle_LargeNegative() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(-720), 0, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-270), 90, accuracy: AppConstants.floatingPointTolerance)
    }
}
