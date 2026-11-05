import CoreGraphics
import Foundation
import Testing
@testable import Sobani

@Suite struct MinimapLayoutTests {

    // MARK: - Basic Window Positioning

    @Test func testWindowAtOriginMapsCorrectly() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: CGPoint(x: 10, y: 10),
            rawTotalBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        // Window at bottom-left corner, 100x200
        let rect = layout.windowRect(for: 0, originY: 0, width: 100, height: 200)

        // scaledX = (0 - 0) * 0.5 + 10 = 10
        // scaledY = (1080 - (0 - 0 + 200)) * 0.5 + 10 = 880 * 0.5 + 10 = 450
        // scaledW = 100 * 0.5 = 50
        // scaledH = 200 * 0.5 = 100
        #expect(abs(rect.origin.x - 10) < 0.001)
        #expect(abs(rect.origin.y - 450) < 0.001)
        #expect(abs(rect.width - 50) < 0.001)
        #expect(abs(rect.height - 100) < 0.001)
    }

    @Test func testWindowAtTopRightMapsToSwiftUITopRight() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: CGPoint(x: 10, y: 10),
            rawTotalBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        // Window at top-right in macOS coords (origin at bottom-left)
        let rect = layout.windowRect(for: 1820, originY: 980, width: 100, height: 100)

        // scaledX = (1820 - 0) * 0.5 + 10 = 920
        // scaledY = (1080 - (980 - 0 + 100)) * 0.5 + 10 = 0 * 0.5 + 10 = 10
        #expect(abs(rect.origin.x - 920) < 0.001)
        #expect(abs(rect.origin.y - 10) < 0.001)
    }

    @Test func testScaleAppliedToSize() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.25,
            offset: .zero,
            rawTotalBounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )

        let rect = layout.windowRect(for: 0, originY: 0, width: 400, height: 300)

        #expect(abs(rect.width - 100) < 0.001)
        #expect(abs(rect.height - 75) < 0.001)
    }

    // MARK: - Multi-Screen with Negative Origin

    @Test func testNegativeOriginScreen() throws {
        // Two screens: main at (0,0) 1920x1080, left at (-1920,0) 1920x1080
        // totalBounds = (-1920, 0, 3840, 1080)
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: CGPoint(x: 20, y: 20),
            rawTotalBounds: CGRect(x: -1920, y: 0, width: 3840, height: 1080)
        )

        // Window on left screen at (-1000, 500) size 200x300
        let rect = layout.windowRect(for: -1000, originY: 500, width: 200, height: 300)

        // scaledX = (-1000 - (-1920)) * 0.1 + 20 = 920 * 0.1 + 20 = 112
        // scaledY = (1080 - (500 - 0 + 300)) * 0.1 + 20 = 280 * 0.1 + 20 = 48
        #expect(abs(rect.origin.x - 112) < 0.001)
        #expect(abs(rect.origin.y - 48) < 0.001)
        #expect(abs(rect.width - 20) < 0.001)
        #expect(abs(rect.height - 30) < 0.001)
    }

    @Test func testWindowOnMainScreenWithNegativeOriginBounds() throws {
        // totalBounds = (-1920, 0, 3840, 1080)
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: CGPoint(x: 20, y: 20),
            rawTotalBounds: CGRect(x: -1920, y: 0, width: 3840, height: 1080)
        )

        // Window on main screen at (100, 100) size 200x200
        let rect = layout.windowRect(for: 100, originY: 100, width: 200, height: 200)

        // scaledX = (100 - (-1920)) * 0.1 + 20 = 2020 * 0.1 + 20 = 222
        // scaledY = (1080 - (100 - 0 + 200)) * 0.1 + 20 = 780 * 0.1 + 20 = 98
        #expect(abs(rect.origin.x - 222) < 0.001)
        #expect(abs(rect.origin.y - 98) < 0.001)
    }

    // MARK: - macOSDelta

    @Test func testMacOSDeltaBasicConversion() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        // Positive width → positive X, positive height → negative Y (SwiftUI→macOS Y flip)
        let delta = layout.macOSDelta(from: CGSize(width: 50, height: 30))
        #expect(abs(delta.x - 100) < 0.001)
        #expect(abs(delta.y - (-60)) < 0.001)
    }

    @Test func testMacOSDeltaScaleFactor() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: CGSize(width: 10, height: 20))
        #expect(abs(delta.x - 100) < 0.001)
        #expect(abs(delta.y - (-200)) < 0.001)
    }

    @Test func testMacOSDeltaZero() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: .zero)
        #expect(abs(delta.x - 0) < 0.001)
        #expect(abs(delta.y - 0) < 0.001)
    }

    /// 倍率が 0 の（描画できない）レイアウトではドラッグ量が無限大にならないことを検証
    @Test func testMacOSDeltaWithZeroScaleIsZero() throws {
        let layout = MinimapLayout(screens: [], scale: 0, offset: .zero, rawTotalBounds: .zero)
        let delta = layout.macOSDelta(from: CGSize(width: 10, height: 20))
        #expect(delta.x.isFinite && delta.y.isFinite)
        #expect(abs(delta.x) < AppConstants.floatingPointTolerance)
        #expect(abs(delta.y) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculate

    private let mainScreen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    /// 範囲が空（.zero・.null）の場合は空のレイアウトになり、NaN・無限大を生まないことを検証
    @Test(arguments: [CGRect.zero, CGRect.null, CGRect(x: 0, y: 0, width: 100, height: 0)])
    @MainActor func testCalculateWithEmptyBoundsIsEmpty(bounds: CGRect) throws {
        let layout = MinimapLayout.calculate(
            in: CGSize(width: 400, height: 300), precomputedBounds: bounds, screenFrames: [mainScreen]
        )
        #expect(layout.isEmpty)
        #expect(layout.scale.isFinite)
        #expect(layout.offset.x.isFinite && layout.offset.y.isFinite)
    }

    /// 表示領域が余白（両側）より小さい場合は空のレイアウトになり、負の倍率で反転しないことを検証
    @Test(arguments: [CGSize.zero, CGSize(width: 20, height: 300), CGSize(width: 400, height: 30)])
    @MainActor func testCalculateWithTooSmallAreaIsEmpty(size: CGSize) throws {
        let layout = MinimapLayout.calculate(in: size, screenFrames: [mainScreen])
        #expect(layout.isEmpty)
        #expect(layout.scale > 0)
    }

    /// スクリーンがない場合は空のレイアウトになることを検証
    @Test @MainActor func testCalculateWithoutScreensIsEmpty() throws {
        let layout = MinimapLayout.calculate(in: CGSize(width: 400, height: 300), screenFrames: [])
        #expect(layout.isEmpty)
    }

    /// 通常の範囲では正の倍率で中央に配置されることを検証
    @Test @MainActor func testCalculateCentersContent() throws {
        let size = CGSize(width: 400, height: 300)
        let padding = AppConstants.managementMinimapPadding
        let layout = MinimapLayout.calculate(in: size, screenFrames: [mainScreen])
        let screen = try #require(layout.screens.first)
        let expectedScale = min((size.width - padding * 2) / 1920, (size.height - padding * 2) / 1080)
        #expect(!layout.isEmpty)
        #expect(abs(layout.scale - expectedScale) < AppConstants.floatingPointTolerance)
        #expect(abs(screen.midX - size.width / 2) < AppConstants.floatingPointTolerance)
        #expect(abs(screen.midY - size.height / 2) < AppConstants.floatingPointTolerance)
    }

    // MARK: - totalBounds

    /// 画面外のウィンドウも範囲に含めることを検証
    @Test func testTotalBoundsIncludesOffscreenWindows() throws {
        let offscreen = CGRect(x: -500, y: 2000, width: 200, height: 100)
        let bounds = MinimapLayout.totalBounds(screenFrames: [mainScreen], windowFrames: [offscreen])
        #expect(bounds.contains(mainScreen))
        #expect(bounds.contains(offscreen))
    }

    /// スクリーンもウィンドウもない場合は .null になることを検証
    @Test func testTotalBoundsOfNothingIsNull() throws {
        #expect(MinimapLayout.totalBounds(screenFrames: [], windowFrames: []).isNull)
    }
}

// MARK: - Position Editor Input

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

// MARK: - Preset Name Validation

/// 管理パネルのプリセット名入力の検証を検証するテスト
@Suite struct PresetNameValidationTests {

    /// 空・空白のみの名前は空として扱われ、重複判定は行われないことを検証
    @Test(arguments: ["", "   ", "\n\t"])
    func blankNameIsEmpty(input: String) throws {
        var checkedNames: [String] = []
        let result = PresetNameValidation.validate(input) { name in
            checkedNames.append(name)
            return false
        }
        #expect(result == .empty)
        #expect(result.validName == nil)
        #expect(checkedNames.isEmpty)
    }

    /// 前後の空白を除いた名前で重複判定され、そのまま確定に使われることを検証
    @Test func nameIsTrimmedBeforeCheck() throws {
        var checkedNames: [String] = []
        let result = PresetNameValidation.validate("  Work  ") { name in
            checkedNames.append(name)
            return false
        }
        #expect(result == .valid("Work"))
        #expect(result.validName == "Work")
        #expect(checkedNames == ["Work"])
    }

    /// 既存の名前と重複する場合は確定できないことを検証
    @Test func duplicateNameIsRejected() throws {
        let result = PresetNameValidation.validate("Home") { $0 == "Home" }
        #expect(result == .duplicate)
        #expect(result.validName == nil)
    }
}

// MARK: - Layout Preset Text

/// レイアウトプリセット一覧の件数表示の書式を検証するテスト
@Suite struct LayoutPresetItemsCountTests {

    private func languageBundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    /// 英語では単数・複数で語形が変わることを検証（システムの言語に関係なく "1 items" にならない）
    @Test func englishUsesPluralForms() throws {
        let bundle = try languageBundle("en")
        #expect(LayoutPresetText.itemsCount(1, bundle: bundle) == "1 item")
        #expect(LayoutPresetText.itemsCount(3, bundle: bundle) == "3 items")
    }

    /// 日本語では件数に「件」が付くことを検証
    @Test func japaneseUsesCounter() throws {
        let bundle = try languageBundle("ja")
        #expect(LayoutPresetText.itemsCount(1, bundle: bundle) == "1件")
        #expect(LayoutPresetText.itemsCount(2, bundle: bundle) == "2件")
    }
}

// MARK: - Window Deletion

/// 管理パネルからの削除でアプリが終了するか（確認が必要か）の判定を検証するテスト
@Suite struct ManagementPanelDeletionTests {

    /// すべてのウィンドウを削除する場合のみ true になることを検証
    @Test func removesAllWindowsOnlyWhenEveryWindowIsDeleted() throws {
        let existing = [1, 2, 3]
        #expect(ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [1, 2, 3], existingIds: existing))
        #expect(ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [1, 2, 3, 99], existingIds: existing))
        #expect(!ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [1, 3], existingIds: existing))
        #expect(!ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [99], existingIds: existing))
    }

    /// 最後の1つを削除する場合は true、ウィンドウがない場合は false になることを検証
    @Test func lastWindowAndEmptyList() throws {
        #expect(ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [7], existingIds: [7]))
        #expect(!ManagementPanelViewModel.deletionRemovesAllWindows(deleting: [7], existingIds: []))
    }
}
