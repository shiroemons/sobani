import Foundation
import Testing
@testable import Sobani

/// 管理パネルの位置エディタの入力変換・検証を検証するテスト
@Suite struct PositionEditorInputTests {

    private func makeFields(_ x: String, _ y: String, _ width: String, _ height: String) -> PositionEditorInput.Fields {
        PositionEditorInput.Fields(x: x, y: y, width: width, height: height)
    }

    /// 表示値は切り捨てではなく四捨五入されることを検証
    @Test func fieldsRoundInsteadOfTruncating() throws {
        let fields = PositionEditorInput.fields(originX: 10.6, originY: -10.6, width: 99.5, height: 0.4)
        #expect(fields == makeFields("11", "-11", "100", "0"))
    }

    /// NaN・無限大の値でもクラッシュせず空文字になることを検証
    @Test func fieldsWithNonFiniteValuesAreEmpty() throws {
        let fields = PositionEditorInput.fields(
            originX: .nan, originY: .infinity, width: -.infinity, height: 10
        )
        #expect(fields == makeFields("", "", "", "10"))
    }

    /// 正しい入力からフレームが得られることを検証
    @Test func parseValidFrame() throws {
        let frame = try #require(PositionEditorInput.parseFrame(makeFields("-120", " 40.5 ", "300", "200")))
        #expect(abs(frame.origin.x - (-120)) < AppConstants.floatingPointTolerance)
        #expect(abs(frame.origin.y - 40.5) < AppConstants.floatingPointTolerance)
        #expect(abs(frame.width - 300) < AppConstants.floatingPointTolerance)
        #expect(abs(frame.height - 200) < AppConstants.floatingPointTolerance)
    }

    /// 数値でない・有限でない・範囲外・正でないサイズの入力を拒否することを検証
    @Test(arguments: [
        ("nan", "0", "100", "100"),
        ("0", "inf", "100", "100"),
        ("0", "-infinity", "100", "100"),
        ("abc", "0", "100", "100"),
        ("", "0", "100", "100"),
        ("0", "0", "0", "100"),
        ("0", "0", "100", "-5"),
        ("1e300", "0", "100", "100"),
        ("0", "0", "100", "1e10"),
    ])
    func parseRejectsInvalidInput(x: String, y: String, width: String, height: String) throws {
        #expect(PositionEditorInput.parseFrame(makeFields(x, y, width, height)) == nil)
    }
}
