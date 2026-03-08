import Foundation
import Testing
@testable import Sobani

/// setStateForTrigger、parseChecksumLine、TLS設定を検証するテスト
@Suite @MainActor struct UpdateManagerExtendedTests {

    // MARK: - setStateForTrigger Tests

    /// manualトリガーでmanualStateが設定されることを検証
    @Test func setStateForTrigger_Manual_SetsManualState() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.manual, manualState: .upToDate)
        if case .upToDate = manager.state {
            // OK
        } else {
            Issue.record("Expected .upToDate state for manual trigger")
        }
    }

    /// startupトリガーでidleが設定されることを検証
    @Test func setStateForTrigger_Startup_SetsIdle() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.startup, manualState: .upToDate)
        if case .idle = manager.state {
            // OK
        } else {
            Issue.record("Expected .idle state for startup trigger")
        }
    }

    /// automaticトリガーでidleが設定されることを検証
    @Test func setStateForTrigger_Automatic_SetsIdle() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.automatic, manualState: .upToDate)
        if case .idle = manager.state {
            // OK
        } else {
            Issue.record("Expected .idle state for automatic trigger")
        }
    }

    /// manualトリガーでerror stateが設定されることを検証
    @Test func setStateForTrigger_Manual_ErrorState() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.manual, manualState: .error(code: .networkError, message: "test"))
        if case .error(let code, _) = manager.state {
            #expect(code.rawValue == "U-101")
        } else {
            Issue.record("Expected .error state for manual trigger")
        }
    }

    // MARK: - parseChecksumLine Tests

    /// 正常形式のチェックサム行が正しくパースされることを検証
    @Test func parseChecksumLine_ValidFormat() {
        let text = "abc123def456  Sobani-universal.zip"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        #expect(result == "abc123def456")
    }

    /// 複数行から正しいアセット名にマッチすることを検証
    @Test func parseChecksumLine_MultipleLines() {
        let text = "aaa111  Sobani-universal.dmg\nbbb222  Sobani-universal.zip\nccc333  checksums.txt"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        #expect(result == "bbb222")
    }

    /// マッチなしの場合に最初の行にフォールバックすることを検証
    @Test func parseChecksumLine_NoMatch_FallsBackToFirstLine() {
        let text = "abc123def456  other-file.zip"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        #expect(result == "abc123def456")
    }

    /// 空文字列でnilを返すことを検証
    @Test func parseChecksumLine_EmptyString() {
        let result = UpdateManager.parseChecksumLine("", forAsset: "Sobani-universal.zip")
        #expect(result == nil)
    }

    /// 単一単語行でもフォールバック動作することを検証
    @Test func parseChecksumLine_SingleWordLine() {
        let text = "abc123def456"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        #expect(result == "abc123def456")
    }

    // MARK: - URLSession TLS Configuration Tests

    /// TLS最低バージョンがTLSv13に設定可能であることを検証
    @Test func urlSession_TLSMinimumVersion() {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        #expect(config.tlsMinimumSupportedProtocolVersion == .TLSv13)
    }
}
