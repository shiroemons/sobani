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
}
