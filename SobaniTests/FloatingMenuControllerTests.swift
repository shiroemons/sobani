import AppKit
import Foundation
import Testing
@testable import Sobani

/// FloatingMenuControllerのテスト可能なロジックを検証するテスト
@Suite @MainActor struct FloatingMenuControllerTests {

    // MARK: - Initial State

    /// 初期状態でisVisibleがfalseであることを検証
    @Test func initialState_isNotVisible() {
        let sut = FloatingMenuController()
        #expect(!sut.isVisible)
    }

    /// 初期状態でdelegateがnilであることを検証
    @Test func initialState_delegateIsNil() {
        let sut = FloatingMenuController()
        #expect(sut.delegate == nil)
    }

    // MARK: - Dismiss

    /// 非表示時にdismissを呼んでもクラッシュしないことを検証
    @Test func dismiss_whenNotVisible_doesNotCrash() {
        let sut = FloatingMenuController()
        sut.dismiss()
        #expect(!sut.isVisible)
    }

    /// dismiss後にisVisibleがfalseになることを検証
    @Test func dismiss_setsIsVisibleToFalse() {
        let sut = FloatingMenuController()
        // Without show(), panel is nil, so dismiss should be safe
        sut.dismiss()
        #expect(!sut.isVisible)
    }

    /// 複数回dismissを呼んでもクラッシュしないことを検証
    @Test func dismiss_calledMultipleTimes_doesNotCrash() {
        let sut = FloatingMenuController()
        sut.dismiss()
        sut.dismiss()
        sut.dismiss()
        #expect(!sut.isVisible)
    }

    // MARK: - Delegate

    /// delegateがweakであることを検証（解放後にnilになる）
    @Test func delegate_isWeak() {
        let sut = FloatingMenuController()

        final class MockDelegate: FloatingMenuDelegate {
            func floatingMenuDidSelectCrop(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectFlip(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectAdjust(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectRemoveBackground(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectClose(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectResetDisplay(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectGhostMode(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectHide(_ menu: FloatingMenuController) {}
            func floatingMenu(_ menu: FloatingMenuController, didChangeOpacity opacity: CGFloat) {}
        }

        var delegate: MockDelegate? = MockDelegate()
        sut.delegate = delegate
        #expect(sut.delegate != nil)

        delegate = nil
        #expect(sut.delegate == nil)
    }

    /// delegateを設定・解除できることを検証
    @Test func delegate_canBeSetAndCleared() {
        let sut = FloatingMenuController()

        final class MockDelegate: FloatingMenuDelegate {
            func floatingMenuDidSelectCrop(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectFlip(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectAdjust(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectRemoveBackground(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectClose(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectResetDisplay(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectGhostMode(_ menu: FloatingMenuController) {}
            func floatingMenuDidSelectHide(_ menu: FloatingMenuController) {}
            func floatingMenu(_ menu: FloatingMenuController, didChangeOpacity opacity: CGFloat) {}
        }

        let delegate = MockDelegate()
        sut.delegate = delegate
        #expect(sut.delegate != nil)

        sut.delegate = nil
        #expect(sut.delegate == nil)

        // Keep delegate alive to prevent premature deallocation
        _ = delegate
    }
}
