import AppKit
import Foundation
import Testing
import os.log
@preconcurrency @testable import Sobani

/// Constants.swiftの定数・ユーティリティの整合性と動作を検証するテスト
@Suite struct ConstantsTests {

    // MARK: - AppConstants 整合性検証

    /// ウィンドウサイズ定数の大小関係が正しいことを検証
    @Test func appConstants_WindowSizeRange() {
        #expect(AppConstants.minImageHeight < AppConstants.defaultWindowHeight)
        #expect(AppConstants.defaultWindowHeight < AppConstants.maxImageHeight)
    }

    /// 不透明度の範囲が0.0〜1.0以内であることを検証
    @Test func appConstants_OpacityRange() {
        #expect(AppConstants.opacityMin < AppConstants.opacityMax)
        #expect(AppConstants.opacityMin >= 0.0)
        #expect(AppConstants.opacityMax <= 1.0)
    }

    /// デバウンスインターバルの大小関係が正しいことを検証
    @Test func appConstants_DebounceIntervals() {
        #expect(AppConstants.screenChangeDebounceInterval < AppConstants.wakeDebounceInterval)
    }

    /// オンボーディングバージョンが1以上であることを検証
    @Test func appConstants_OnboardingVersion() {
        #expect(AppConstants.Onboarding.currentVersion >= 1)
    }

    /// オンボーディングウィンドウサイズが正の値であることを検証
    @Test func appConstants_OnboardingSize() {
        #expect(AppConstants.Onboarding.width > 0)
        #expect(AppConstants.Onboarding.height > 0)
    }

    // MARK: - MenuItemTag 検証

    /// 全タグのrawValueが一意であることを検証
    @Test func menuItemTag_AllValuesUnique() {
        let rawValues = MenuItemTag.allCases.map { $0.rawValue }
        #expect(rawValues.count == Set(rawValues).count, "MenuItemTag に重複するrawValueがあります")
    }

    /// 全タグ値が1001以上であることを検証
    @Test(arguments: MenuItemTag.allCases)
    func menuItemTag_AllValuesAboveMinimum(tag: MenuItemTag) {
        #expect(tag.rawValue >= 1001, "\(tag) のrawValue \(tag.rawValue) が 1001 未満です")
    }

    /// MenuItemTagのケース数が想定通りであることを検証
    @Test func menuItemTag_CaseCount() {
        #expect(MenuItemTag.allCases.count == 29)
    }

    // MARK: - Screen Restoration / Wake Retry 定数検証

    /// Screen Restoration定数の正値と整合性を検証
    @Test func appConstants_ScreenRestoration() {
        #expect(AppConstants.screenMatchTolerance > 0)
        #expect(AppConstants.screenIntersectionThreshold > 0)
        #expect(AppConstants.wakeInitialDelay > 0)
    }

    /// Wake Retry定数の整合性を検証（threshold < maxAttempts）
    @Test func appConstants_WakeRetryRelationship() {
        #expect(AppConstants.wakeRetryCountThreshold < AppConstants.wakeRetryMaxAttempts)
        #expect(AppConstants.wakeRetryCountThreshold >= 0)
        #expect(AppConstants.wakeRetryMaxAttempts > 0)
        #expect(AppConstants.wakeRetryInterval > 0)
    }

    /// Fallback定数の正値を検証
    @Test func appConstants_FallbackValues() {
        #expect(AppConstants.fallbackScreenSize.width > 0)
        #expect(AppConstants.fallbackScreenSize.height > 0)
        #expect(AppConstants.fallbackScreenHeight > 0)
    }

    /// 浮動小数点許容誤差・UI定数の正値を検証
    @Test func appConstants_MiscPositiveValues() {
        #expect(AppConstants.floatingPointTolerance > 0)
        #expect(AppConstants.statusBarIconSize > 0)
        #expect(AppConstants.menuWindowMinWidth > 0)
        #expect(AppConstants.menuTabPadding > 0)
        #expect(AppConstants.layoutDialogFieldWidth > 0)
        #expect(AppConstants.layoutDialogFieldHeight > 0)
    }

    // MARK: - AppSupportDirectory テスト

    /// カスタムbaseDirectoryが指定された場合にそのパスが返されることを検証
    @Test func appSupportDirectory_CustomBaseDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)
        #expect(result?.path == tempDir.path)
    }

    /// 存在しないディレクトリが自動作成されることを検証
    @Test func appSupportDirectory_CreatesNonexistentDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(!FileManager.default.fileExists(atPath: tempDir.path))

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)

        #expect(result != nil)
        #expect(FileManager.default.fileExists(atPath: tempDir.path))
    }

    /// 既存ディレクトリがそのまま返されることを検証
    @Test func appSupportDirectory_ExistingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)
        #expect(result?.path == tempDir.path)
    }

    /// nil baseDirectoryでデフォルトパスが使用されることを検証
    @Test func appSupportDirectory_NilBaseDirectoryUsesDefault() {
        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: nil, logger: logger)
        #expect(result != nil)
        if let path = result?.path {
            #expect(path.hasSuffix("/Sobani"), "パスが /Sobani で終わるべき: \(path)")
        }
    }

    // MARK: - ImageFileDialog テスト

    /// makeOpenPanelのデフォルト設定が正しいことを検証
    @MainActor @Test func imageFileDialog_DefaultSettings() {
        let panel = ImageFileDialog.makeOpenPanel()
        #expect(!panel.allowsMultipleSelection)
        #expect(!panel.canChooseDirectories)
        #expect(panel.level == .floating)
        #expect(panel.allowedContentTypes.count == 5)
    }

    /// カスタムタイトルとメッセージが反映されることを検証
    @MainActor @Test func imageFileDialog_CustomTitleAndMessage() {
        let panel = ImageFileDialog.makeOpenPanel(title: "Custom Title", message: "Custom Message")
        #expect(panel.title == "Custom Title")
        #expect(panel.message == "Custom Message")
    }

    /// promptにローカライズ値が設定されることを検証
    @MainActor @Test func imageFileDialog_PromptIsSet() {
        let panel = ImageFileDialog.makeOpenPanel()
        #expect(!panel.prompt.isEmpty)
    }

    // MARK: - NSMenu.item(withMenuTag:) テスト

    /// 該当タグのメニューアイテムが正しく検索されることを検証
    @Test func nsMenu_ItemWithMenuTag_FindsItem() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.quit.rawValue
        menu.addItem(item)

        let found = menu.item(withMenuTag: .quit)
        #expect(found != nil)
        #expect(found?.title == "Test")
    }

    /// 存在しないタグでnilが返されることを検証
    @Test func nsMenu_ItemWithMenuTag_ReturnsNilForMissingTag() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.quit.rawValue
        menu.addItem(item)

        #expect(menu.item(withMenuTag: .addImage) == nil)
    }

    /// 空メニューでnilが返されることを検証
    @Test func nsMenu_ItemWithMenuTag_EmptyMenu() {
        let menu = NSMenu()
        #expect(menu.item(withMenuTag: .quit) == nil)
    }

    // MARK: - L() ローカライズヘルパーテスト

    /// L()が空でない文字列を返すことを検証
    @Test func localizeHelper_ReturnsNonEmptyString() {
        let result = L("dialog.select")
        #expect(!result.isEmpty)
    }

    /// L()に空キーを渡した場合に空文字列が返されることを検証
    @Test func localizeHelper_HandlesEmptyKey() {
        let result = L("")
        #expect(result.isEmpty)
    }

    /// makeOpenPanelの5つのUTTypeが全て含まれていることを検証
    @MainActor @Test func imageFileDialog_AllContentTypesPresent() {
        let panel = ImageFileDialog.makeOpenPanel()
        let types = panel.allowedContentTypes
        #expect(types.contains(.png))
        #expect(types.contains(.jpeg))
        #expect(types.contains(.gif))
        #expect(types.contains(.tiff))
        #expect(types.contains(.heic))
    }
}
