import Testing
@preconcurrency @testable import Sobani

/// 回転バウンディングボックス計算と角度正規化の正確性を検証するテスト
@Suite struct GeometryUtilsTests {

    // MARK: - rotatedBoundingBox Tests

    /// 0度回転でサイズが変わらないことを検証
    @Test func rotatedBoundingBox_ZeroDegrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 0)
        #expect(abs(size.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - 50) < AppConstants.floatingPointTolerance)
    }

    /// 90度回転で幅と高さが入れ替わることを検証
    @Test func rotatedBoundingBox_90Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 90)
        #expect(abs(size.width - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - 100) < AppConstants.floatingPointTolerance)
    }

    /// 180度回転でサイズが元に戻ることを検証
    @Test func rotatedBoundingBox_180Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 180)
        #expect(abs(size.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - 50) < AppConstants.floatingPointTolerance)
    }

    /// 270度回転で幅と高さが入れ替わることを検証
    @Test func rotatedBoundingBox_270Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 50, angleDegrees: 270)
        #expect(abs(size.width - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - 100) < AppConstants.floatingPointTolerance)
    }

    /// 正方形の45度回転で対角線長のバウンディングボックスになることを検証
    @Test func rotatedBoundingBox_45Degrees() {
        let size = GeometryUtils.rotatedBoundingBox(width: 100, height: 100, angleDegrees: 45)
        // 正方形を45度回転: 対角線の長さ = 100 * sqrt(2) ≈ 141.42
        let expected = 100 * sqrt(2.0)
        #expect(abs(size.width - expected) < AppConstants.floatingPointTolerance)
        #expect(abs(size.height - expected) < AppConstants.floatingPointTolerance)
    }

    /// 非正方形の45度回転でバウンディングボックスが正しく計算されることを検証
    @Test func rotatedBoundingBox_45Degrees_NonSquare() {
        let size = GeometryUtils.rotatedBoundingBox(width: 200, height: 100, angleDegrees: 45)
        // 200x100を45°回転: |200*cos45°|+|100*sin45°| = 141.42+70.71 = 212.13
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

    // MARK: - normalizeAngle Tests

    /// 0-359度の範囲内の角度がそのまま返されることを検証
    @Test func normalizeAngle_AlreadyNormalized() {
        #expect(abs(GeometryUtils.normalizeAngle(45) - 45) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(0) - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(359) - 359) < AppConstants.floatingPointTolerance)
    }

    /// 負の角度が0-359度の範囲に正規化されることを検証
    @Test func normalizeAngle_Negative() {
        #expect(abs(GeometryUtils.normalizeAngle(-90) - 270) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(-360) - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(-1) - 359) < AppConstants.floatingPointTolerance)
    }

    /// 360度以上の角度が0-359度の範囲に正規化されることを検証
    @Test func normalizeAngle_Overflow() {
        #expect(abs(GeometryUtils.normalizeAngle(360) - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(450) - 90) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(720) - 0) < AppConstants.floatingPointTolerance)
    }

    /// 大きな負の角度が正しく正規化されることを検証
    @Test func normalizeAngle_LargeNegative() {
        #expect(abs(GeometryUtils.normalizeAngle(-720) - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(GeometryUtils.normalizeAngle(-270) - 90) < AppConstants.floatingPointTolerance)
    }
}
