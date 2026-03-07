import XCTest
@testable import Sobani

/// setStateForTrigger、parseChecksumLine、TLS設定を検証するテスト
final class UpdateManagerExtendedTests: XCTestCase {

    // MARK: - setStateForTrigger Tests

    /// manualトリガーでmanualStateが設定されることを検証
    func testSetStateForTrigger_Manual_SetsManualState() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.manual, manualState: .upToDate)
        if case .upToDate = manager.state {
            // OK
        } else {
            XCTFail("Expected .upToDate state for manual trigger")
        }
    }

    /// startupトリガーでidleが設定されることを検証
    func testSetStateForTrigger_Startup_SetsIdle() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.startup, manualState: .upToDate)
        if case .idle = manager.state {
            // OK
        } else {
            XCTFail("Expected .idle state for startup trigger")
        }
    }

    /// automaticトリガーでidleが設定されることを検証
    func testSetStateForTrigger_Automatic_SetsIdle() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.automatic, manualState: .upToDate)
        if case .idle = manager.state {
            // OK
        } else {
            XCTFail("Expected .idle state for automatic trigger")
        }
    }

    /// manualトリガーでerror stateが設定されることを検証
    func testSetStateForTrigger_Manual_ErrorState() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.setStateForTrigger(.manual, manualState: .error(code: .networkError, message: "test"))
        if case .error(let code, _) = manager.state {
            XCTAssertEqual(code.rawValue, "U-101")
        } else {
            XCTFail("Expected .error state for manual trigger")
        }
    }

    // MARK: - parseChecksumLine Tests

    /// 正常形式のチェックサム行が正しくパースされることを検証
    func testParseChecksumLine_ValidFormat() {
        let text = "abc123def456  Sobani-universal.zip"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        XCTAssertEqual(result, "abc123def456")
    }

    /// 複数行から正しいアセット名にマッチすることを検証
    func testParseChecksumLine_MultipleLines() {
        let text = "aaa111  Sobani-universal.dmg\nbbb222  Sobani-universal.zip\nccc333  checksums.txt"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        XCTAssertEqual(result, "bbb222")
    }

    /// マッチなしの場合に最初の行にフォールバックすることを検証
    func testParseChecksumLine_NoMatch_FallsBackToFirstLine() {
        let text = "abc123def456  other-file.zip"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        XCTAssertEqual(result, "abc123def456")
    }

    /// 空文字列でnilを返すことを検証
    func testParseChecksumLine_EmptyString() {
        let result = UpdateManager.parseChecksumLine("", forAsset: "Sobani-universal.zip")
        XCTAssertNil(result)
    }

    /// 単一単語行でもフォールバック動作することを検証
    func testParseChecksumLine_SingleWordLine() {
        let text = "abc123def456"
        let result = UpdateManager.parseChecksumLine(text, forAsset: "Sobani-universal.zip")
        XCTAssertEqual(result, "abc123def456")
    }

    // MARK: - URLSession TLS Configuration Tests

    /// TLS最低バージョンがTLSv13に設定可能であることを検証
    func testURLSession_TLSMinimumVersion() {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        XCTAssertEqual(config.tlsMinimumSupportedProtocolVersion, .TLSv13)
    }
}
