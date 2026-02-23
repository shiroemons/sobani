import XCTest
@testable import Sobani

final class GeometryUtilsTests: XCTestCase {

    // MARK: - rotatedBoundingBox Tests

    func testRotatedBoundingBox_ZeroDegrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 0)
        XCTAssertEqual(size.width, 100, accuracy: 0.01)
        XCTAssertEqual(size.height, 50, accuracy: 0.01)
    }

    func testRotatedBoundingBox_90Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 90)
        XCTAssertEqual(size.width, 50, accuracy: 0.01)
        XCTAssertEqual(size.height, 100, accuracy: 0.01)
    }

    func testRotatedBoundingBox_180Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 180)
        XCTAssertEqual(size.width, 100, accuracy: 0.01)
        XCTAssertEqual(size.height, 50, accuracy: 0.01)
    }

    func testRotatedBoundingBox_45Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 100, angleDegrees: 45)
        // 正方形を45度回転: 対角線の長さ = 100 * sqrt(2) ≈ 141.42
        let expected = 100 * sqrt(2.0)
        XCTAssertEqual(size.width, expected, accuracy: 0.01)
        XCTAssertEqual(size.height, expected, accuracy: 0.01)
    }

    func testRotatedBoundingBox_NegativeAngle() {
        let positive = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 30)
        let negative = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: -30)
        XCTAssertEqual(positive.width, negative.width, accuracy: 0.01)
        XCTAssertEqual(positive.height, negative.height, accuracy: 0.01)
    }

    // MARK: - normalizeAngle Tests

    func testNormalizeAngle_AlreadyNormalized() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(45), 45, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(0), 0, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(359), 359, accuracy: 0.01)
    }

    func testNormalizeAngle_Negative() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(-90), 270, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-360), 0, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(-1), 359, accuracy: 0.01)
    }

    func testNormalizeAngle_OverFlow() {
        XCTAssertEqual(GeometryUtils.normalizeAngle(360), 0, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(450), 90, accuracy: 0.01)
        XCTAssertEqual(GeometryUtils.normalizeAngle(720), 0, accuracy: 0.01)
    }
}
