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
}

// MARK: - ScrollEndDebouncer

/// スクロール操作の終わりを待ってから 1 回だけ処理を実行するデバウンサ
///
/// ホイールやトラックパッドのスクロールはイベントが連続して届くため、
/// 1 回のスクロール操作を 1 つの編集履歴としてまとめて記録するのに使う。
@MainActor
final class ScrollEndDebouncer {
    private static let settleDelay: Duration = .milliseconds(300)

    private var pendingTask: Task<Void, Never>?
    private var pendingAction: (() -> Void)?

    /// 呼ぶたびに待ち時間をリセットし、最後の呼び出しから一定時間後に `action` を 1 回だけ実行する
    func schedule(_ action: @escaping () -> Void) {
        pendingAction = action
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// 待機中の処理があれば今すぐ実行する（次の操作の前に履歴の順序を保つため）
    func flush() {
        pendingTask?.cancel()
        pendingTask = nil
        let action = pendingAction
        pendingAction = nil
        action?()
    }

    /// 待機中の処理を実行せずに破棄する
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingAction = nil
    }
}
