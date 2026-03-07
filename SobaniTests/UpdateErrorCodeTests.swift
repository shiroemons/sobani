import XCTest
@testable import Sobani

/// エラーコードのrawValue一貫性、一意性、トラブルシューティングキーの正確性を検証するテスト
final class UpdateErrorCodeTests: XCTestCase {

    // MARK: - Raw Value Tests

    /// 各エラーコードのrawValueが仕様通りの文字列であることを検証
    func testUpdateErrorCode_RawValues() {
        // Check phase
        XCTAssertEqual(UpdateErrorCode.networkError.rawValue, "U-101")
        XCTAssertEqual(UpdateErrorCode.fetchError.rawValue, "U-102")
        XCTAssertEqual(UpdateErrorCode.parseError.rawValue, "U-103")
        // Download phase
        XCTAssertEqual(UpdateErrorCode.downloadError.rawValue, "U-201")
        XCTAssertEqual(UpdateErrorCode.fileNotFound.rawValue, "U-202")
        XCTAssertEqual(UpdateErrorCode.checksumFailed.rawValue, "U-203")
        // Install phase - ZIP
        XCTAssertEqual(UpdateErrorCode.zipExtractFailed.rawValue, "U-301")
        XCTAssertEqual(UpdateErrorCode.zipAppNotFound.rawValue, "U-302")
        XCTAssertEqual(UpdateErrorCode.zipPrepareFailed.rawValue, "U-303")
        // Install phase - DMG
        XCTAssertEqual(UpdateErrorCode.dmgMountFailed.rawValue, "U-401")
        XCTAssertEqual(UpdateErrorCode.dmgAppNotFound.rawValue, "U-402")
        XCTAssertEqual(UpdateErrorCode.dmgPrepareFailed.rawValue, "U-403")
        // Replace & Restart phase
        XCTAssertEqual(UpdateErrorCode.locationError.rawValue, "U-501")
        XCTAssertEqual(UpdateErrorCode.backupFailed.rawValue, "U-502")
        XCTAssertEqual(UpdateErrorCode.installFailed.rawValue, "U-503")
    }

    // MARK: - Uniqueness Test

    /// すべてのエラーコードが一意のrawValueを持つことを検証
    func testUpdateErrorCode_AllCodesAreUnique() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]
        let rawValues = allCodes.map { $0.rawValue }
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "All error codes must have unique raw values")
    }

    // MARK: - Pattern Matching Test

    /// UpdateState.errorのパターンマッチングでコードとメッセージが取得できることを検証
    func testUpdateState_ErrorPatternMatching() {
        let state = UpdateState.error(code: .networkError, message: "test message")
        if case .error(let code, let message) = state {
            XCTAssertEqual(code, .networkError)
            XCTAssertEqual(message, "test message")
        } else {
            XCTFail("Expected .error state")
        }
    }

    // MARK: - TroubleshootingKey Tests

    /// すべてのエラーコードが空でないトラブルシューティングキーを持つことを検証
    func testTroubleshootingKey_allCodesReturnNonEmptyKey() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        for code in allCodes {
            XCTAssertFalse(code.troubleshootingKey.isEmpty, "\(code) should have a non-empty troubleshootingKey")
        }
    }

    /// トラブルシューティングキーにエラーコードのrawValueが含まれることを検証
    func testTroubleshootingKey_containsErrorCode() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        for code in allCodes {
            XCTAssertTrue(code.troubleshootingKey.contains(code.rawValue),
                          "\(code).troubleshootingKey should contain \(code.rawValue)")
        }
    }

    /// 各フェーズの代表的なトラブルシューティングキーが正しい値であることを検証
    func testTroubleshootingKey_specificValues() {
        XCTAssertEqual(UpdateErrorCode.networkError.troubleshootingKey, "update.hint.U-101")
        XCTAssertEqual(UpdateErrorCode.downloadError.troubleshootingKey, "update.hint.U-201")
        XCTAssertEqual(UpdateErrorCode.zipExtractFailed.troubleshootingKey, "update.hint.U-301")
        XCTAssertEqual(UpdateErrorCode.dmgMountFailed.troubleshootingKey, "update.hint.U-401")
        XCTAssertEqual(UpdateErrorCode.locationError.troubleshootingKey, "update.hint.U-501")
    }

    /// すべてのトラブルシューティングキーが一意であることを検証
    func testTroubleshootingKey_allCodesHaveUniqueKeys() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        let keys = allCodes.map { $0.troubleshootingKey }
        let uniqueKeys = Set(keys)
        XCTAssertEqual(keys.count, uniqueKeys.count, "All troubleshootingKeys should be unique")
    }
}
