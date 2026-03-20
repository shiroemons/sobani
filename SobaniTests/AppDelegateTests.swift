import Testing
@testable import Sobani

@Suite("AppDelegate Tests")
struct AppDelegateTests {

    // MARK: - shouldQuitApp Tests

    @Test("shouldQuitApp: ウィンドウなし＆レイアウト適用中でない → 終了する")
    func shouldQuitAppNoWindowsNotApplying() {
        #expect(AppDelegate.shouldQuitApp(windowCount: 0, isApplyingLayout: false))
    }

    @Test("shouldQuitApp: ウィンドウあり＆レイアウト適用中でない → 終了しない")
    func shouldQuitAppWithWindows() {
        #expect(!AppDelegate.shouldQuitApp(windowCount: 3, isApplyingLayout: false))
    }

    @Test("shouldQuitApp: ウィンドウなし＆レイアウト適用中 → 終了しない")
    func shouldQuitAppApplyingLayout() {
        #expect(!AppDelegate.shouldQuitApp(windowCount: 0, isApplyingLayout: true))
    }

    @Test("shouldQuitApp: ウィンドウあり＆レイアウト適用中 → 終了しない")
    func shouldQuitAppWithWindowsAndApplying() {
        #expect(!AppDelegate.shouldQuitApp(windowCount: 1, isApplyingLayout: true))
    }

    // MARK: - resolveImageName Tests

    @Test("resolveImageName: デフォルト画像名と一致する場合 → デフォルトを返す")
    func resolveImageNameDefault() {
        let result = AppDelegate.resolveImageName(
            "default", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: デフォルト画像名と一致する場合（登録画像あり） → デフォルトを返す")
    func resolveImageNameDefaultEvenIfRegistered() {
        let result = AppDelegate.resolveImageName(
            "default", defaultImageName: "default", registeredImageExists: true
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: 登録画像が存在する場合 → その名前を返す")
    func resolveImageNameRegistered() {
        let result = AppDelegate.resolveImageName(
            "custom.png", defaultImageName: "default", registeredImageExists: true
        )
        #expect(result.resolvedName == "custom.png")
        #expect(result.isDefault == false)
    }

    @Test("resolveImageName: 登録画像が存在しない場合 → デフォルトにフォールバック")
    func resolveImageNameFallback() {
        let result = AppDelegate.resolveImageName(
            "missing.png", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: 空文字列で登録画像が存在しない場合 → デフォルトにフォールバック")
    func resolveImageNameEmptyString() {
        let result = AppDelegate.resolveImageName(
            "", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    // MARK: - migrateWindowIds Tests

    @Test("migrateWindowIds: 全てのIDが有効な場合 → 割り当てなし")
    func migrateWindowIdsAllValid() {
        let result = AppDelegate.migrateWindowIds(existingIds: [1, 2, 3], legacyId: 0)
        #expect(result.assignments.isEmpty)
        #expect(result.nextId == 4)
    }

    @Test("migrateWindowIds: legacyIdを含む場合 → 新しいIDを割り当て")
    func migrateWindowIdsWithLegacy() {
        let result = AppDelegate.migrateWindowIds(existingIds: [1, 0, 3], legacyId: 0)
        #expect(result.assignments.count == 1)
        #expect(result.assignments[0].oldIndex == 1)
        #expect(result.assignments[0].newId == 4)
        #expect(result.nextId == 5)
    }

    @Test("migrateWindowIds: 空配列の場合 → 割り当てなし、nextId=1")
    func migrateWindowIdsEmpty() {
        let result = AppDelegate.migrateWindowIds(existingIds: [], legacyId: 0)
        #expect(result.assignments.isEmpty)
        #expect(result.nextId == 1)
    }

    @Test("migrateWindowIds: 全てlegacyIdの場合 → 全要素に新IDを割り当て")
    func migrateWindowIdsAllLegacy() {
        let result = AppDelegate.migrateWindowIds(existingIds: [0, 0, 0], legacyId: 0)
        #expect(result.assignments.count == 3)
        #expect(result.assignments[0] == (oldIndex: 0, newId: 1))
        #expect(result.assignments[1] == (oldIndex: 1, newId: 2))
        #expect(result.assignments[2] == (oldIndex: 2, newId: 3))
        #expect(result.nextId == 4)
    }

    @Test("migrateWindowIds: 連番でないIDの場合 → maxから連番を割り当て")
    func migrateWindowIdsNonSequential() {
        let result = AppDelegate.migrateWindowIds(existingIds: [5, 0, 10], legacyId: 0)
        #expect(result.assignments.count == 1)
        #expect(result.assignments[0].oldIndex == 1)
        #expect(result.assignments[0].newId == 11)
        #expect(result.nextId == 12)
    }
}
