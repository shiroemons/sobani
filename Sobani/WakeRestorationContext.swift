import Cocoa

/// スリープ復帰時のウィンドウ復元に必要な状態を集約する構造体
struct WakeRestorationContext: Sendable {
    var states: [Int: WindowState] = [:]
    var displayIDs: [Int: CGDirectDisplayID] = [:]
    var screenFrames: [CGDirectDisplayID: NSRect] = [:]
    var windowOrigins: [Int: NSPoint] = [:]
    var isActive: Bool = false
    var retryCount: Int = 0

    mutating func clear() {
        self = Self()
    }
}

/// 起動直後のディスプレイ構成変化に追従してアンカー復元を再試行するための状態。
///
/// ログイン直後はディスプレイの認識順でプライマリディスプレイ（グローバル座標の原点）が
/// 一時的に変わることがあり、起動時に一度配置しただけでは位置がずれる。
struct LaunchRestorationContext: Sendable {
    /// windowId → 意図した位置（アンカー付きの保存状態）
    var states: [Int: WindowState] = [:]

    /// 追従対象のウィンドウが残っている間はアクティブ
    var isActive: Bool { !states.isEmpty }

    mutating func clear() {
        self = Self()
    }

    /// ユーザーが手動で動かしたウィンドウは以後の再適用対象から外す
    mutating func release(windowId: Int) {
        states[windowId] = nil
    }
}
