import Foundation
import Testing
@testable import Sobani

/// レイアウトプリセットのリネーム機能を検証するテスト
@Suite @MainActor struct LayoutPresetRenameTests {
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

    private func makeState(
        imageName: String = AppConstants.defaultImageName,
        originX: CGFloat = 100
    ) -> WindowState {
        WindowState(
            imageName: imageName,
            originX: originX,
            originY: 200,
            width: 300,
            height: 400,
            isFlippedHorizontally: false,
            rotationAngle: 0,
            opacityLevel: 1.0,
            windowId: 0
        )
    }

    // MARK: - Rename Tests

    /// プリセットのリネームが正しく動作しcreatedAtが保持されることを検証
    @Test func renamePresetSuccess() throws {
        let states = [makeState(imageName: "rename.png", originX: 42)]
        presetManager.savePreset(name: "OldName", states: states)

        let oldPreset = try #require(presetManager.loadPreset(named: "OldName"))
        let result = presetManager.renamePreset(from: "OldName", to: "NewName")

        #expect(result)
        #expect(presetManager.loadPreset(named: "OldName") == nil)

        let renamed = try #require(presetManager.loadPreset(named: "NewName"))
        #expect(renamed.name == "NewName")
        #expect(renamed.states == states)
        #expect(renamed.createdAt == oldPreset.createdAt)
    }

    /// 存在しないプリセットのリネームでfalseが返されることを検証
    @Test func renameNonExistentPreset() {
        let result = presetManager.renamePreset(from: "DoesNotExist", to: "NewName")
        #expect(!result)
    }

    /// 同名へのリネームが成功し内容が保持されることを検証
    @Test func renameSameName() throws {
        let states = [makeState(imageName: "same.png")]
        presetManager.savePreset(name: "SameName", states: states)

        let result = presetManager.renamePreset(from: "SameName", to: "SameName")
        #expect(result)

        let loaded = try #require(presetManager.loadPreset(named: "SameName"))
        #expect(loaded.name == "SameName")
        #expect(loaded.states == states)
    }

    /// リネームで既存プリセットが上書きされることを検証
    @Test func renameOverwritesExisting() throws {
        presetManager.savePreset(name: "Source", states: [makeState(originX: 100)])
        presetManager.savePreset(name: "Target", states: [makeState(originX: 200)])

        let result = presetManager.renamePreset(from: "Source", to: "Target")
        #expect(result)

        #expect(presetManager.loadPreset(named: "Source") == nil)
        let target = try #require(presetManager.loadPreset(named: "Target"))
        #expect(target.states == [makeState(originX: 100)])
    }

    /// Unicode文字を含む名前へのリネームが正しく動作することを検証
    @Test func renameWithSpecialCharacters() throws {
        let states = [makeState(imageName: "special.png")]
        presetManager.savePreset(name: "Normal", states: states)

        let result = presetManager.renamePreset(from: "Normal", to: "特殊文字レイアウト")
        #expect(result)

        #expect(presetManager.loadPreset(named: "Normal") == nil)
        let renamed = try #require(presetManager.loadPreset(named: "特殊文字レイアウト"))
        #expect(renamed.states == states)
    }
}
