import Foundation
import Testing
@testable import Sobani

/// レイアウトプリセットの複数WindowState保存・プロパティ保持・削除後の存在確認を検証するテスト
@Suite @MainActor struct LayoutPresetManagerExtendedTests {
    let tempDirectory: URL
    let presetManager: LayoutPresetManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
        presetManager = LayoutPresetManager(baseDirectory: tempDirectory)
    }

    // MARK: - Helpers

    private func makeState(
        imageName: String = AppConstants.defaultImageName,
        originX: CGFloat = 100,
        originY: CGFloat = 200,
        width: CGFloat = 300,
        height: CGFloat = 400,
        isFlippedHorizontally: Bool = false,
        rotationAngle: CGFloat = 0,
        opacityLevel: CGFloat = 1.0,
        windowId: Int = 0
    ) -> WindowState {
        WindowState(
            imageName: imageName,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle,
            opacityLevel: opacityLevel,
            windowId: windowId
        )
    }

    // MARK: - Multiple States Tests

    /// 複数WindowStateを持つプリセットが正しく保存・読み込みされることを検証
    @Test func multipleStatesInPreset() {
        let states = [
            makeState(imageName: "img1.png", originX: 10, originY: 20, windowId: 1),
            makeState(imageName: "img2.png", originX: 30, originY: 40, windowId: 2),
            makeState(imageName: "img3.png", originX: 50, originY: 60, windowId: 3),
            makeState(imageName: "img4.png", originX: 70, originY: 80, windowId: 4),
            makeState(imageName: "img5.png", originX: 90, originY: 100, windowId: 5)
        ]
        presetManager.savePreset(name: "FiveWindows", states: states)

        let loaded = presetManager.loadPreset(named: "FiveWindows")
        #expect(loaded != nil)
        #expect(loaded?.states.count == 5)
        #expect(loaded?.states == states)
    }

    /// WindowStateの全プロパティ(反転・回転・透過率・位置・サイズ)が保持されることを検証
    @Test func presetStatesPreserveWindowProperties() throws {
        let states = [
            makeState(
                imageName: "flipped.png",
                originX: 150,
                originY: 250,
                width: 500,
                height: 600,
                isFlippedHorizontally: true,
                rotationAngle: 45,
                opacityLevel: 0.7,
                windowId: 3
            ),
            makeState(
                imageName: "rotated.png",
                originX: 300,
                originY: 400,
                width: 200,
                height: 250,
                isFlippedHorizontally: false,
                rotationAngle: 180,
                opacityLevel: 0.5,
                windowId: 7
            )
        ]
        presetManager.savePreset(name: "PropertiesTest", states: states)

        let loaded = try #require(presetManager.loadPreset(named: "PropertiesTest"))
        let loadedStates = loaded.states

        #expect(loadedStates[0].imageName == "flipped.png")
        #expect(loadedStates[0].isFlippedHorizontally)
        #expect(abs(loadedStates[0].rotationAngle - 45) < AppConstants.floatingPointTolerance)
        #expect(abs(loadedStates[0].opacityLevel - 0.7) < AppConstants.floatingPointTolerance)
        #expect(loadedStates[0].windowId == 3)
        #expect(abs(loadedStates[0].originX - 150) < AppConstants.floatingPointTolerance)
        #expect(abs(loadedStates[0].originY - 250) < AppConstants.floatingPointTolerance)
        #expect(abs(loadedStates[0].width - 500) < AppConstants.floatingPointTolerance)
        #expect(abs(loadedStates[0].height - 600) < AppConstants.floatingPointTolerance)

        #expect(loadedStates[1].imageName == "rotated.png")
        #expect(!loadedStates[1].isFlippedHorizontally)
        #expect(abs(loadedStates[1].rotationAngle - 180) < AppConstants.floatingPointTolerance)
        #expect(abs(loadedStates[1].opacityLevel - 0.5) < AppConstants.floatingPointTolerance)
        #expect(loadedStates[1].windowId == 7)
    }

    // MARK: - Delete Then Exists Tests

    /// 削除後にpresetExistsがfalseを返すことを検証
    @Test func deleteThenPresetExistsFalse() {
        presetManager.savePreset(name: "WillBeDeleted", states: [makeState()])
        #expect(presetManager.presetExists(named: "WillBeDeleted"))

        presetManager.deletePreset(named: "WillBeDeleted")
        #expect(!presetManager.presetExists(named: "WillBeDeleted"))
    }

}
