import XCTest
import os.log
@testable import Sobani

/// Constants.swiftの定数・ユーティリティの整合性と動作を検証するテスト
final class ConstantsTests: XCTestCase {

    // MARK: - AppConstants 整合性検証

    /// ウィンドウサイズ定数の大小関係が正しいことを検証
    func testAppConstants_WindowSizeRange() {
        XCTAssertLessThan(AppConstants.minImageHeight, AppConstants.defaultWindowHeight)
        XCTAssertLessThan(AppConstants.defaultWindowHeight, AppConstants.maxImageHeight)
    }

    /// 不透明度の範囲が0.0〜1.0以内であることを検証
    func testAppConstants_OpacityRange() {
        XCTAssertLessThan(AppConstants.opacityMin, AppConstants.opacityMax)
        XCTAssertGreaterThanOrEqual(AppConstants.opacityMin, 0.0)
        XCTAssertLessThanOrEqual(AppConstants.opacityMax, 1.0)
    }

    /// デバウンスインターバルの大小関係が正しいことを検証
    func testAppConstants_DebounceIntervals() {
        XCTAssertLessThan(AppConstants.screenChangeDebounceInterval, AppConstants.wakeDebounceInterval)
    }

    /// オンボーディングバージョンが1以上であることを検証
    func testAppConstants_OnboardingVersion() {
        XCTAssertGreaterThanOrEqual(AppConstants.Onboarding.currentVersion, 1)
    }

    /// オンボーディングウィンドウサイズが正の値であることを検証
    func testAppConstants_OnboardingSize() {
        XCTAssertGreaterThan(AppConstants.Onboarding.width, 0)
        XCTAssertGreaterThan(AppConstants.Onboarding.height, 0)
    }

    // MARK: - MenuItemTag 検証

    /// 全タグのrawValueが一意であることを検証
    func testMenuItemTag_AllValuesUnique() {
        let allTags: [MenuItemTag] = [
            .resetToDefault, .defaultImage, .changeDefaultImage, .resetDefaultImage,
            .addImage, .showCount, .flipHorizontal, .adjust,
            .moveToFront, .moveToBack, .close, .launchAtLogin,
            .checkForUpdates, .quit, .changeImageSubmenu, .addNewWindowSubmenu,
            .otherSubmenu, .showOnboarding, .removeBackground,
            .flipContext, .adjustPanelContext, .layoutSubmenu,
            .saveLayout, .deleteLayout, .updateLayout, .createLayout,
            .settingsSubmenu, .bulkResetSubmenu, .renameLayout
        ]
        let rawValues = allTags.map { $0.rawValue }
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "MenuItemTag に重複するrawValueがあります")
    }

    /// 全タグ値が1001以上であることを検証
    func testMenuItemTag_AllValuesAboveMinimum() {
        let allTags: [MenuItemTag] = [
            .resetToDefault, .defaultImage, .changeDefaultImage, .resetDefaultImage,
            .addImage, .showCount, .flipHorizontal, .adjust,
            .moveToFront, .moveToBack, .close, .launchAtLogin,
            .checkForUpdates, .quit, .changeImageSubmenu, .addNewWindowSubmenu,
            .otherSubmenu, .showOnboarding, .removeBackground,
            .flipContext, .adjustPanelContext, .layoutSubmenu,
            .saveLayout, .deleteLayout, .updateLayout, .createLayout,
            .settingsSubmenu, .bulkResetSubmenu, .renameLayout
        ]
        for tag in allTags {
            XCTAssertGreaterThanOrEqual(tag.rawValue, 1001, "\(tag) のrawValue \(tag.rawValue) が 1001 未満です")
        }
    }

    /// MenuItemTagのケース数が想定通りであることを検証
    func testMenuItemTag_CaseCount() {
        let allTags: [MenuItemTag] = [
            .resetToDefault, .defaultImage, .changeDefaultImage, .resetDefaultImage,
            .addImage, .showCount, .flipHorizontal, .adjust,
            .moveToFront, .moveToBack, .close, .launchAtLogin,
            .checkForUpdates, .quit, .changeImageSubmenu, .addNewWindowSubmenu,
            .otherSubmenu, .showOnboarding, .removeBackground,
            .flipContext, .adjustPanelContext, .layoutSubmenu,
            .saveLayout, .deleteLayout, .updateLayout, .createLayout,
            .settingsSubmenu, .bulkResetSubmenu, .renameLayout
        ]
        XCTAssertEqual(allTags.count, 29)
    }

    // MARK: - AppSupportDirectory テスト

    /// カスタムbaseDirectoryが指定された場合にそのパスが返されることを検証
    func testAppSupportDirectory_CustomBaseDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)
        XCTAssertEqual(result?.path, tempDir.path)
    }

    /// 存在しないディレクトリが自動作成されることを検証
    func testAppSupportDirectory_CreatesNonexistentDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)

        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }

    /// 既存ディレクトリがそのまま返されることを検証
    func testAppSupportDirectory_ExistingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: tempDir, logger: logger)
        XCTAssertEqual(result?.path, tempDir.path)
    }

    /// nil baseDirectoryでデフォルトパスが使用されることを検証
    func testAppSupportDirectory_NilBaseDirectoryUsesDefault() {
        let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "Test")
        let result = AppSupportDirectory.url(baseDirectory: nil, logger: logger)
        XCTAssertNotNil(result)
        if let path = result?.path {
            XCTAssertTrue(path.hasSuffix("/Sobani"), "パスが /Sobani で終わるべき: \(path)")
        }
    }

    // MARK: - ImageFileDialog テスト

    /// makeOpenPanelのデフォルト設定が正しいことを検証
    func testImageFileDialog_DefaultSettings() {
        let panel = ImageFileDialog.makeOpenPanel()
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertEqual(panel.allowedContentTypes.count, 5)
    }

    /// カスタムタイトルとメッセージが反映されることを検証
    func testImageFileDialog_CustomTitleAndMessage() {
        let panel = ImageFileDialog.makeOpenPanel(title: "Custom Title", message: "Custom Message")
        XCTAssertEqual(panel.title, "Custom Title")
        XCTAssertEqual(panel.message, "Custom Message")
    }

    /// promptにローカライズ値が設定されることを検証
    func testImageFileDialog_PromptIsSet() {
        let panel = ImageFileDialog.makeOpenPanel()
        XCTAssertFalse(panel.prompt.isEmpty)
    }

    // MARK: - NSMenu.item(withMenuTag:) テスト

    /// 該当タグのメニューアイテムが正しく検索されることを検証
    func testNSMenu_ItemWithMenuTag_FindsItem() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.quit.rawValue
        menu.addItem(item)

        let found = menu.item(withMenuTag: .quit)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Test")
    }

    /// 存在しないタグでnilが返されることを検証
    func testNSMenu_ItemWithMenuTag_ReturnsNilForMissingTag() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.quit.rawValue
        menu.addItem(item)

        XCTAssertNil(menu.item(withMenuTag: .addImage))
    }

    /// 空メニューでnilが返されることを検証
    func testNSMenu_ItemWithMenuTag_EmptyMenu() {
        let menu = NSMenu()
        XCTAssertNil(menu.item(withMenuTag: .quit))
    }
}
