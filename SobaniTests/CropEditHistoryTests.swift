import Foundation
import Testing
@testable import Sobani

/// CropEditHistoryクラスの編集履歴管理（undo/redo/reset）を検証するテスト
@Suite @MainActor struct CropEditHistoryTests {

    // MARK: - 初期状態テスト

    /// 初期状態ではcanUndo/canRedoがfalseであることを検証
    @Test func initialState_cannotUndoOrRedo() {
        let history = CropEditHistory(initialState: .full)
        #expect(!history.canUndo)
        #expect(!history.canRedo)
    }

    // MARK: - 基本フローテスト

    /// record→undo→redoの基本フローが正しく動作することを検証
    @Test func basicFlow_recordUndoRedo() throws {
        let initial = CropRect.full
        let history = CropEditHistory(initialState: initial)

        let modified = CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        history.record(modified)

        #expect(history.canUndo)
        #expect(!history.canRedo)

        let undone = try #require(history.undo())
        #expect(abs(undone.x - initial.x) < AppConstants.floatingPointTolerance)
        #expect(abs(undone.y - initial.y) < AppConstants.floatingPointTolerance)
        #expect(abs(undone.width - initial.width) < AppConstants.floatingPointTolerance)
        #expect(abs(undone.height - initial.height) < AppConstants.floatingPointTolerance)

        #expect(!history.canUndo)
        #expect(history.canRedo)

        let redone = try #require(history.redo())
        #expect(abs(redone.x - modified.x) < AppConstants.floatingPointTolerance)
        #expect(abs(redone.y - modified.y) < AppConstants.floatingPointTolerance)
        #expect(abs(redone.width - modified.width) < AppConstants.floatingPointTolerance)
        #expect(abs(redone.height - modified.height) < AppConstants.floatingPointTolerance)

        #expect(history.canUndo)
        #expect(!history.canRedo)
    }

    // MARK: - Redoクリアテスト

    /// undo後に新しい変更を記録するとredoヒストリがクリアされることを検証
    @Test func undoThenRecord_clearsRedoHistory() throws {
        let history = CropEditHistory(initialState: .full)

        let stateA = CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let stateB = CropRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        history.record(stateA)
        history.record(stateB)

        // stateAの状態にundo
        _ = history.undo()
        #expect(history.canRedo)

        // 新しい変更を記録するとredoヒストリがクリアされる
        let stateC = CropRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        history.record(stateC)

        #expect(!history.canRedo)
        #expect(history.canUndo)
    }

    // MARK: - 重複スキップテスト

    /// isEffectivelyEqualなstateは記録されないことを検証
    @Test func record_skipsDuplicateState() {
        let history = CropEditHistory(initialState: .full)
        let tiny = 0.0000001 as CGFloat
        // .fullとisEffectivelyEqualな値（許容誤差内）
        let almostFull = CropRect(x: tiny, y: tiny, width: 1 - tiny, height: 1 - tiny)
        history.record(almostFull)

        // 重複なので記録されない → canUndo=false
        #expect(!history.canUndo)
    }

    // MARK: - 複数undo/redoテスト

    /// 複数回recordした後の連続undo→連続redoが正しく動作することを検証
    @Test func multipleRecords_sequentialUndoAndRedo() throws {
        let initial = CropRect.full
        let history = CropEditHistory(initialState: initial)

        let stateA = CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let stateB = CropRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let stateC = CropRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        history.record(stateA)
        history.record(stateB)
        history.record(stateC)

        // 連続undo: stateC→stateB→stateA→initial
        let undo1 = try #require(history.undo())
        #expect(abs(undo1.x - stateB.x) < AppConstants.floatingPointTolerance)

        let undo2 = try #require(history.undo())
        #expect(abs(undo2.x - stateA.x) < AppConstants.floatingPointTolerance)

        let undo3 = try #require(history.undo())
        #expect(abs(undo3.x - initial.x) < AppConstants.floatingPointTolerance)

        #expect(!history.canUndo)
        #expect(history.canRedo)

        // 連続redo: initial→stateA→stateB→stateC
        let redo1 = try #require(history.redo())
        #expect(abs(redo1.x - stateA.x) < AppConstants.floatingPointTolerance)

        let redo2 = try #require(history.redo())
        #expect(abs(redo2.x - stateB.x) < AppConstants.floatingPointTolerance)

        let redo3 = try #require(history.redo())
        #expect(abs(redo3.x - stateC.x) < AppConstants.floatingPointTolerance)

        #expect(history.canUndo)
        #expect(!history.canRedo)
    }

    // MARK: - resetテスト

    /// reset()後は初期状態のみが残り、undo/redoできないことを検証
    @Test func reset_keepsOnlyInitialState() throws {
        let initial = CropRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        let history = CropEditHistory(initialState: initial)

        history.record(CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8))
        history.record(CropRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6))

        history.reset()

        #expect(!history.canUndo)
        #expect(!history.canRedo)

        // undoはnilを返す（初期状態のみ残っている）
        let result = history.undo()
        #expect(result == nil)
    }

    // MARK: - 空履歴でのundo/redoテスト

    /// 履歴が空の状態でundo()はnilを返すことを検証
    @Test func undo_onEmptyHistory_returnsNil() {
        let history = CropEditHistory(initialState: .full)
        let result = history.undo()
        #expect(result == nil)
    }

    /// 履歴が空の状態でredo()はnilを返すことを検証
    @Test func redo_onEmptyHistory_returnsNil() {
        let history = CropEditHistory(initialState: .full)
        let result = history.redo()
        #expect(result == nil)
    }

    // MARK: - undo後のrecordで前方履歴がトリムされることを検証

    /// undo後にrecordすると前方の履歴が削除されることを検証
    @Test func recordAfterUndo_trimsFowardHistory() throws {
        let history = CropEditHistory(initialState: .full)

        let stateA = CropRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let stateB = CropRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let stateC = CropRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

        history.record(stateA)
        history.record(stateB)

        // stateAへundo
        _ = history.undo()

        // stateB以降の前方履歴をトリムしてstateCを記録
        history.record(stateC)

        // redoはできない（前方履歴がトリムされたため）
        #expect(!history.canRedo)

        // undoするとstateAに戻る
        let undone = try #require(history.undo())
        #expect(abs(undone.x - stateA.x) < AppConstants.floatingPointTolerance)

        // さらにundoすると初期状態（full）に戻る
        let undone2 = try #require(history.undo())
        #expect(abs(undone2.x - CropRect.full.x) < AppConstants.floatingPointTolerance)

        #expect(!history.canUndo)
    }

}
