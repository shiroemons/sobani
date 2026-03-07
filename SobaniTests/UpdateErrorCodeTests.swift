import Testing
@preconcurrency @testable import Sobani

/// エラーコードのrawValue一貫性、一意性、トラブルシューティングキーの正確性を検証するテスト
@Suite struct UpdateErrorCodeTests {

    // MARK: - Raw Value Tests

    /// 各エラーコードのrawValueが仕様通りの文字列であることを検証
    @Test func updateErrorCode_RawValues() {
        // Check phase
        #expect(UpdateErrorCode.networkError.rawValue == "U-101")
        #expect(UpdateErrorCode.fetchError.rawValue == "U-102")
        #expect(UpdateErrorCode.parseError.rawValue == "U-103")
        // Download phase
        #expect(UpdateErrorCode.downloadError.rawValue == "U-201")
        #expect(UpdateErrorCode.fileNotFound.rawValue == "U-202")
        #expect(UpdateErrorCode.checksumFailed.rawValue == "U-203")
        // Install phase - ZIP
        #expect(UpdateErrorCode.zipExtractFailed.rawValue == "U-301")
        #expect(UpdateErrorCode.zipAppNotFound.rawValue == "U-302")
        #expect(UpdateErrorCode.zipPrepareFailed.rawValue == "U-303")
        // Install phase - DMG
        #expect(UpdateErrorCode.dmgMountFailed.rawValue == "U-401")
        #expect(UpdateErrorCode.dmgAppNotFound.rawValue == "U-402")
        #expect(UpdateErrorCode.dmgPrepareFailed.rawValue == "U-403")
        // Replace & Restart phase
        #expect(UpdateErrorCode.locationError.rawValue == "U-501")
        #expect(UpdateErrorCode.backupFailed.rawValue == "U-502")
        #expect(UpdateErrorCode.installFailed.rawValue == "U-503")
    }

    // MARK: - Uniqueness Test

    /// すべてのエラーコードが一意のrawValueを持つことを検証
    @Test func updateErrorCode_AllCodesAreUnique() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]
        let rawValues = allCodes.map { $0.rawValue }
        #expect(rawValues.count == Set(rawValues).count, "All error codes must have unique raw values")
    }

    // MARK: - Pattern Matching Test

    /// UpdateState.errorのパターンマッチングでコードとメッセージが取得できることを検証
    @Test func updateState_ErrorPatternMatching() {
        let state = UpdateState.error(code: .networkError, message: "test message")
        if case .error(let code, let message) = state {
            #expect(code == .networkError)
            #expect(message == "test message")
        } else {
            Issue.record("Expected .error state")
        }
    }

    // MARK: - TroubleshootingKey Tests

    /// すべてのエラーコードが空でないトラブルシューティングキーを持つことを検証
    @Test func troubleshootingKey_allCodesReturnNonEmptyKey() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        for code in allCodes {
            #expect(!code.troubleshootingKey.isEmpty, "\(code) should have a non-empty troubleshootingKey")
        }
    }

    /// トラブルシューティングキーにエラーコードのrawValueが含まれることを検証
    @Test func troubleshootingKey_containsErrorCode() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        for code in allCodes {
            #expect(code.troubleshootingKey.contains(code.rawValue),
                    "\(code).troubleshootingKey should contain \(code.rawValue)")
        }
    }

    /// 各フェーズの代表的なトラブルシューティングキーが正しい値であることを検証
    @Test func troubleshootingKey_specificValues() {
        #expect(UpdateErrorCode.networkError.troubleshootingKey == "update.hint.U-101")
        #expect(UpdateErrorCode.downloadError.troubleshootingKey == "update.hint.U-201")
        #expect(UpdateErrorCode.zipExtractFailed.troubleshootingKey == "update.hint.U-301")
        #expect(UpdateErrorCode.dmgMountFailed.troubleshootingKey == "update.hint.U-401")
        #expect(UpdateErrorCode.locationError.troubleshootingKey == "update.hint.U-501")
    }

    /// すべてのトラブルシューティングキーが一意であることを検証
    @Test func troubleshootingKey_allCodesHaveUniqueKeys() {
        let allCodes: [UpdateErrorCode] = [
            .networkError, .fetchError, .parseError,
            .downloadError, .fileNotFound, .checksumFailed,
            .zipExtractFailed, .zipAppNotFound, .zipPrepareFailed,
            .dmgMountFailed, .dmgAppNotFound, .dmgPrepareFailed,
            .locationError, .backupFailed, .installFailed
        ]

        let keys = allCodes.map { $0.troubleshootingKey }
        let uniqueKeys = Set(keys)
        #expect(keys.count == uniqueKeys.count, "All troubleshootingKeys should be unique")
    }
}
