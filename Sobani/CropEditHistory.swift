import Foundation
import os.log

// MARK: - CropEditHistory

@MainActor
final class CropEditHistory {
    private var states: [CropRect]
    private var currentIndex: Int

    private let logger = Logger(category: "CropEditHistory")

    // MARK: - Computed Properties

    var canUndo: Bool { currentIndex > 0 }
    var canRedo: Bool { currentIndex < states.count - 1 }

    // MARK: - Init

    init(initialState: CropRect) {
        states = [initialState]
        currentIndex = 0
        logger.debug("CropEditHistory initialized with initial state")
    }

    // MARK: - History Operations

    /// 新しい状態を記録する。重複はスキップし、Redo履歴は破棄する
    func record(_ state: CropRect) {
        let current = states[currentIndex]
        guard !state.isEffectivelyEqual(to: current) else {
            logger.debug("Skipping duplicate state")
            return
        }

        // Redo履歴を破棄
        if currentIndex < states.count - 1 {
            states.removeSubrange((currentIndex + 1)...)
            logger.debug("Trimmed redo history")
        }

        states.append(state)
        currentIndex = states.count - 1
        logger.debug("Recorded state at index \(self.currentIndex)")
    }

    /// 一つ前の状態に戻る。戻れない場合は nil を返す
    func undo() -> CropRect? {
        guard canUndo else {
            logger.debug("Cannot undo: already at initial state")
            return nil
        }
        currentIndex -= 1
        logger.debug("Undo to index \(self.currentIndex)")
        return states[currentIndex]
    }

    /// 一つ次の状態に進む。進めない場合は nil を返す
    func redo() -> CropRect? {
        guard canRedo else {
            logger.debug("Cannot redo: already at latest state")
            return nil
        }
        currentIndex += 1
        logger.debug("Redo to index \(self.currentIndex)")
        return states[currentIndex]
    }

    /// 初期状態のみを残し、インデックスをリセットする
    func reset() {
        let initial = states[0]
        states = [initial]
        currentIndex = 0
        logger.debug("Reset history to initial state")
    }
}
