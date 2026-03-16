import Foundation
import Testing
@testable import Sobani

/// レイアウトプリセットの保存・読み込み・削除・リネーム、ファイル名サニタイズ、エッジケース、Codable/Equatable準拠を検証するテスト
@Suite @MainActor struct LayoutPresetManagerTests {
    let tempDirectory: URL
    let presetManager: LayoutPresetManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
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

    private func writePreset(
        name: String, originX: CGFloat, createdAt: Date,
        encoder: JSONEncoder, directory: URL,
        id: UUID = UUID()
    ) throws {
        let preset = LayoutPreset(id: id, name: name, createdAt: createdAt, states: [makeState(originX: originX)])
        let data = try encoder.encode(preset)
        try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
    }

    // MARK: - Save and Load Tests

    /// プリセットの保存と読み込みのラウンドトリップが正しく動作することを検証
    @Test func saveAndLoadPresetRoundTrip() {
        let states = [makeState(imageName: "image1.png"), makeState(imageName: "image2.png")]
        presetManager.savePreset(name: "TestPreset", states: states)

        let loaded = presetManager.loadPreset(named: "TestPreset")
        #expect(loaded != nil)
        #expect(loaded?.name == "TestPreset")
        #expect(loaded?.states == states)
    }

    /// 複数プリセットがすべて読み込まれることを検証
    @Test func loadPresetsReturnsAllPresets() {
        presetManager.savePreset(name: "Preset1", states: [makeState(originX: 1)])
        presetManager.savePreset(name: "Preset2", states: [makeState(originX: 2)])
        presetManager.savePreset(name: "Preset3", states: [makeState(originX: 3)])

        let all = presetManager.loadPresets()
        #expect(all.count == 3)

        let names = Set(all.map { $0.name })
        #expect(names.contains("Preset1"))
        #expect(names.contains("Preset2"))
        #expect(names.contains("Preset3"))
    }

    /// プリセットがcreatedAtの降順でソートされることを検証
    @Test func loadPresetsOrderedByCreatedAtDescending() throws {
        // Save all presets first, then overwrite JSON to control createdAt
        presetManager.savePreset(name: "OldPreset", states: [makeState(originX: 1)])
        presetManager.savePreset(name: "MiddlePreset", states: [makeState(originX: 2)])
        presetManager.savePreset(name: "NewPreset", states: [makeState(originX: 3)])

        // Overwrite createdAt with controlled dates
        let layoutsDir = try #require(presetManager.layoutsDirectoryURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let now = Date()

        try writePreset(name: "OldPreset", originX: 1, createdAt: now.addingTimeInterval(-200),
                       encoder: encoder, directory: layoutsDir)
        try writePreset(name: "MiddlePreset", originX: 2, createdAt: now.addingTimeInterval(-100),
                       encoder: encoder, directory: layoutsDir)
        try writePreset(name: "NewPreset", originX: 3, createdAt: now,
                       encoder: encoder, directory: layoutsDir)

        let all = presetManager.loadPresets()
        #expect(all.count == 3)
        #expect(all[0].name == "NewPreset")
        #expect(all[1].name == "MiddlePreset")
        #expect(all[2].name == "OldPreset")
    }

    /// 同名プリセットの上書き保存が正しく動作することを検証
    @Test func overwritePreset() {
        let firstStates = [makeState(imageName: "first.png")]
        presetManager.savePreset(name: "MyPreset", states: firstStates)
        #expect(presetManager.loadPreset(named: "MyPreset")?.states == firstStates)

        let secondStates = [makeState(imageName: "second.png"), makeState(imageName: "third.png")]
        presetManager.savePreset(name: "MyPreset", states: secondStates)

        let loaded = presetManager.loadPreset(named: "MyPreset")
        #expect(loaded?.states == secondStates)
        #expect(loaded?.states.count == 2)
    }

    // MARK: - Delete Tests

    /// プリセットの削除が正しく動作することを検証
    @Test func deletePreset() {
        presetManager.savePreset(name: "ToDelete", states: [makeState()])
        #expect(presetManager.loadPreset(named: "ToDelete") != nil)

        presetManager.deletePreset(named: "ToDelete")
        #expect(presetManager.loadPreset(named: "ToDelete") == nil)
    }

    /// 存在しないプリセットの削除でクラッシュしないことを検証
    @Test func deleteNonExistentPreset() {
        // Should not crash
        presetManager.deletePreset(named: "NonExistent")
        #expect(presetManager.loadPresets().isEmpty)
    }

    // MARK: - presetExists Tests

    /// 存在するプリセットに対してtrueが返されることを検証
    @Test func presetExistsTrue() {
        presetManager.savePreset(name: "Exists", states: [makeState()])
        #expect(presetManager.presetExists(named: "Exists"))
    }

    /// 存在しないプリセットに対してfalseが返されることを検証
    @Test func presetExistsFalse() {
        #expect(!presetManager.presetExists(named: "DoesNotExist"))
    }

    // MARK: - Sanitized File Name Tests

    /// 特殊文字を含むプリセット名の保存と読み込みが正しく動作することを検証
    @Test func sanitizedFileNameSpecialCharacters() {
        let specialName = "test/\\:*?\"<>|name"
        let states = [makeState(imageName: "special.png")]
        presetManager.savePreset(name: specialName, states: states)

        let loaded = presetManager.loadPreset(named: specialName)
        #expect(loaded != nil)
        #expect(loaded?.name == specialName)
        #expect(loaded?.states == states)
    }

    /// パストラバーサルを含む名前でlayoutsディレクトリ外に保存されないことを検証
    @Test func sanitizedFileNamePathTraversal() throws {
        let dangerousName = "../../../etc/passwd"
        let states = [makeState(imageName: "safe.png")]
        presetManager.savePreset(name: dangerousName, states: states)

        let loaded = presetManager.loadPreset(named: dangerousName)
        #expect(loaded != nil)
        #expect(loaded?.name == dangerousName)
        #expect(loaded?.states == states)

        // Verify the file was saved inside the layouts directory, not at a traversed path
        let layoutsDir = presetManager.layoutsDirectoryURL
        #expect(layoutsDir != nil)

        // ファイルがlayoutsディレクトリ内に保存されたことを検証
        let layoutsDirUnwrapped = try #require(presetManager.layoutsDirectoryURL)
        let resolvedLayoutsDir = layoutsDirUnwrapped.standardizedFileURL.path
        let files = try FileManager.default.contentsOfDirectory(at: layoutsDirUnwrapped, includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        #expect(!jsonFiles.isEmpty, "Preset file should exist in layouts directory")
        for file in jsonFiles {
            #expect(file.standardizedFileURL.path.hasPrefix(resolvedLayoutsDir),
                    "Preset file must be inside layouts directory: \(file.path)")
        }
    }

    // MARK: - Edge Case Tests

    /// 空文字名のプリセット保存が"unnamed"フォールバックで動作することを検証
    @Test func savePreset_EmptyName_UsesUnnamedFallback() {
        let states = [makeState(imageName: "test.png")]
        presetManager.savePreset(name: "", states: states)

        // sanitizedFileName returns "unnamed" for empty string
        let loaded = presetManager.loadPreset(named: "")
        #expect(loaded != nil)
        #expect(loaded?.name == "")
        #expect(loaded?.states == states)
    }

    /// ドット名のプリセットが"unnamed"フォールバックで安全に保存されることを検証
    @Test func savePreset_DotName_UsesUnnamedFallback() {
        let states = [makeState(imageName: "dot.png")]
        presetManager.savePreset(name: ".", states: states)

        let loaded = presetManager.loadPreset(named: ".")
        #expect(loaded != nil)
        #expect(loaded?.name == ".")
        #expect(loaded?.states == states)
    }

    /// 空のWindowState配列を持つプリセットが正しく保存・読み込みされることを検証
    @Test func emptyStatesArray() {
        presetManager.savePreset(name: "EmptyPreset", states: [])

        let loaded = presetManager.loadPreset(named: "EmptyPreset")
        #expect(loaded != nil)
        #expect(loaded?.name == "EmptyPreset")
        #expect(loaded?.states == [])
    }

    /// 不正なJSONファイルがスキップされ有効なプリセットのみ読み込まれることを検証
    @Test func invalidJSONSkipped() throws {
        // Write invalid JSON file directly into the layouts directory
        let layoutsDir = try #require(presetManager.layoutsDirectoryURL)

        let invalidFile = layoutsDir.appendingPathComponent("invalid.json")
        try "{ not valid json }}}".write(to: invalidFile, atomically: true, encoding: .utf8)

        // Also save a valid preset
        presetManager.savePreset(name: "ValidPreset", states: [makeState()])

        let all = presetManager.loadPresets()
        // Should load at least the valid preset without crashing
        #expect(all.contains(where: { $0.name == "ValidPreset" }))
    }

    /// Unicode(日本語)プリセット名の保存と読み込みが正しく動作することを検証
    @Test func unicodePresetName() {
        let japaneseName = "お気に入りレイアウト"
        let states = [makeState(imageName: "character.png")]
        presetManager.savePreset(name: japaneseName, states: states)

        let loaded = presetManager.loadPreset(named: japaneseName)
        #expect(loaded != nil)
        #expect(loaded?.name == japaneseName)
        #expect(loaded?.states == states)
    }

    // MARK: - LayoutPreset Codable/Equatable Tests

    /// LayoutPresetのCodableエンコード・デコードが正しく動作することを検証
    @Test func layoutPresetCodable() throws {
        let states = [makeState(imageName: "test.png", originX: 50, originY: 60)]
        let preset = LayoutPreset(name: "CodableTest", createdAt: Date(), states: states)

        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutPreset.self, from: data)

        #expect(decoded == preset)
        #expect(decoded.id == preset.id)
    }

    /// idフィールドのないJSONからデコードするとUUIDが自動生成されることを検証（後方互換性）
    @Test func layoutPresetCodableMigrationGeneratesId() throws {
        let states = [makeState(imageName: "test.png")]
        let date = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // idフィールドなしのJSONを手動構築
        let legacyPreset = LayoutPreset(name: "Legacy", createdAt: date, states: states)
        var json = try JSONSerialization.jsonObject(
            with: encoder.encode(legacyPreset), options: []
        ) as? [String: Any]
        json?.removeValue(forKey: "id")
        let legacyData = try JSONSerialization.data(withJSONObject: json as Any)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LayoutPreset.self, from: legacyData)

        #expect(decoded.name == "Legacy")
        #expect(decoded.states == states)
        // idが自動生成されている（ゼロUUIDではない）
        #expect(decoded.id != UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
    }

    /// LayoutPresetのEquatable比較が正しく動作することを検証
    @Test func layoutPresetEquatable() {
        let date = Date()
        let states = [makeState(imageName: "eq.png")]
        let sharedId = UUID()

        let preset1 = LayoutPreset(id: sharedId, name: "Same", createdAt: date, states: states)
        let preset2 = LayoutPreset(id: sharedId, name: "Same", createdAt: date, states: states)
        #expect(preset1 == preset2)

        let preset3 = LayoutPreset(id: sharedId, name: "Different", createdAt: date, states: states)
        #expect(preset1 != preset3)

        let differentStates = [makeState(imageName: "other.png")]
        let preset4 = LayoutPreset(id: sharedId, name: "Same", createdAt: date, states: differentStates)
        #expect(preset1 != preset4)

        // 異なるidを持つプリセットは等しくない
        let preset5 = LayoutPreset(id: UUID(), name: "Same", createdAt: date, states: states)
        #expect(preset1 != preset5)
    }

    // MARK: - Load Non-Existent Tests

    /// 存在しないプリセットの読み込みでnilが返されることを検証
    @Test func loadPresetNonExistent() {
        let loaded = presetManager.loadPreset(named: "NeverSaved")
        #expect(loaded == nil)
    }

    // MARK: - Directory Tests

    /// layoutsディレクトリが自動作成されることを検証
    @Test func layoutsDirectoryCreated() throws {
        let layoutsDir = try #require(presetManager.layoutsDirectoryURL)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: layoutsDir.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    // MARK: - Cache Tests

    /// 連続してloadPresetsを呼んだとき同一の結果を返すことを検証
    @Test func loadPresetsReturnsCachedResult() {
        presetManager.savePreset(name: "CachePreset1", states: [makeState(originX: 10)])
        presetManager.savePreset(name: "CachePreset2", states: [makeState(originX: 20)])

        let first = presetManager.loadPresets()
        let second = presetManager.loadPresets()
        #expect(first == second)
        #expect(first.count == 2)
    }

    /// savePreset後にloadPresetsが新しいプリセットを含む結果を返すことを検証
    @Test func cacheInvalidatedAfterSave() {
        presetManager.savePreset(name: "BeforeSave", states: [makeState(originX: 1)])
        let before = presetManager.loadPresets()
        #expect(before.count == 1)

        presetManager.savePreset(name: "AfterSave", states: [makeState(originX: 2)])
        let after = presetManager.loadPresets()
        #expect(after.count == 2)
        #expect(after.contains(where: { $0.name == "AfterSave" }))
    }

    /// deletePreset後にloadPresetsが削除済みプリセットを含まないことを検証
    @Test func cacheInvalidatedAfterDelete() {
        presetManager.savePreset(name: "ToDeleteCache", states: [makeState()])
        let before = presetManager.loadPresets()
        #expect(before.contains(where: { $0.name == "ToDeleteCache" }))

        presetManager.deletePreset(named: "ToDeleteCache")
        let after = presetManager.loadPresets()
        #expect(!after.contains(where: { $0.name == "ToDeleteCache" }))
    }

    /// renamePreset後にloadPresetsが新しい名前のプリセットを含むことを検証
    @Test func cacheInvalidatedAfterRename() {
        presetManager.savePreset(name: "OldCacheName", states: [makeState()])
        let before = presetManager.loadPresets()
        #expect(before.contains(where: { $0.name == "OldCacheName" }))
        let originalId = before.first { $0.name == "OldCacheName" }?.id

        let result = presetManager.renamePreset(from: "OldCacheName", to: "NewCacheName")
        #expect(result)

        let after = presetManager.loadPresets()
        #expect(!after.contains(where: { $0.name == "OldCacheName" }))
        #expect(after.contains(where: { $0.name == "NewCacheName" }))
        // リネーム後もidが保持されることを検証
        #expect(after.first { $0.name == "NewCacheName" }?.id == originalId)
    }

    // MARK: - Restore Tests

    /// 削除したプリセットがrestorePresetで復元されることを検証
    @Test func restorePresetAfterDelete() {
        let states = [makeState(imageName: "restore.png")]
        presetManager.savePreset(name: "ToRestore", states: states)

        let original = presetManager.loadPreset(named: "ToRestore")
        #expect(original != nil)

        presetManager.deletePreset(named: "ToRestore")
        #expect(presetManager.loadPreset(named: "ToRestore") == nil)

        if let original {
            presetManager.restorePreset(original)
        }

        let restored = presetManager.loadPreset(named: "ToRestore")
        #expect(restored != nil)
        #expect(restored?.name == "ToRestore")
        #expect(restored?.states == states)
        #expect(restored?.createdAt == original?.createdAt)
    }

    /// restorePresetがcreatedAtを保持することを検証
    @Test func restorePresetPreservesCreatedAt() throws {
        let states = [makeState(imageName: "preserve.png")]
        presetManager.savePreset(name: "PreserveDate", states: states)

        let original = try #require(presetManager.loadPreset(named: "PreserveDate"))
        let originalDate = original.createdAt

        presetManager.deletePreset(named: "PreserveDate")

        // Wait briefly to ensure Date() would produce a different timestamp
        presetManager.restorePreset(original)

        let restored = try #require(presetManager.loadPreset(named: "PreserveDate"))
        #expect(restored.createdAt == originalDate)
    }

}
