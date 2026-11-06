import Foundation
import Testing
@testable import Sobani

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
