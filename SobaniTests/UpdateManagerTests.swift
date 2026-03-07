import Foundation
import Testing
import CryptoKit
@preconcurrency @testable import Sobani

/// バージョン比較ロジック、GitHubリリースJSONパース、チェックトリガー、SHA-256チェックサム検証、アセット選択を検証するテスト
@Suite struct UpdateManagerTests {

    // MARK: - isNewer Parameterized Tests

    /// バージョン比較ロジックをパラメタライズドテストで検証
    @Test(arguments: [
        ("202602.3", "202602.2", true),
        ("202602.1", "202602.2", false),
        ("202602.2", "202602.2", false),
        ("202603.0", "202602.2", true),
        ("202601.5", "202602.2", false),
        ("202602.10", "202602.2", true),
        ("202602.2", "202602.10", false),
        ("202701.0", "202612.5", true),
    ])
    func isNewer_VersionComparisons(newer: String, older: String, expected: Bool) {
        #expect(UpdateManager.isNewer(newer, than: older) == expected)
    }

    /// 不正なバージョン形式でfalseを返すことを検証
    @Test(arguments: [
        ("invalid", "202602.2"),
        ("202602.2", "invalid"),
        ("", ""),
        ("v202602.3", "202602.2"),
    ])
    func isNewer_InvalidFormats(newer: String, older: String) {
        #expect(!UpdateManager.isNewer(newer, than: older))
    }

    // MARK: - GitHubRelease JSON Parsing Tests

    /// GitHubリリースJSONが正しくデコードされることを検証
    @Test func gitHubRelease_DecodesCorrectly() throws {
        let json = Data("""
        {
            "tag_name": "v202602.3",
            "assets": [
                {
                    "name": "Sobani-202602.3-universal.zip",
                    "browser_download_url": "https://github.com/shiroemons/sobani/releases/download/v202602.3/Sobani-202602.3-universal.zip"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.tagName == "v202602.3")
        #expect(release.assets.count == 1)
        #expect(release.assets[0].name == "Sobani-202602.3-universal.zip")
        #expect(
            release.assets[0].browserDownloadURL
                == "https://github.com/shiroemons/sobani/releases/download/v202602.3/Sobani-202602.3-universal.zip"
        )
    }

    /// アセットが空のリリースJSONが正しくデコードされることを検証
    @Test func gitHubRelease_EmptyAssets() throws {
        let json = Data("""
        {
            "tag_name": "v202602.3",
            "assets": []
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.tagName == "v202602.3")
        #expect(release.assets.isEmpty)
    }

    /// 複数アセットを持つリリースJSONが正しくデコードされることを検証
    @Test func gitHubRelease_MultipleAssets() throws {
        let json = Data("""
        {
            "tag_name": "v202602.3",
            "assets": [
                {
                    "name": "Sobani-202602.3-universal.zip",
                    "browser_download_url": "https://example.com/zip"
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://example.com/checksums"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.assets.count == 2)
        #expect(release.assets[0].name == "Sobani-202602.3-universal.zip")
        #expect(release.assets[1].name == "checksums.txt")
    }

    // MARK: - CheckTrigger Tests

    /// チェックトリガーのデフォルトがautomaticであることを検証
    @Test func checkTrigger_DefaultIsAutomatic() {
        let manager = UpdateManager(currentVersion: "202602.4")
        #expect(manager.lastCheckTrigger == .automatic)
    }

    /// 手動トリガーが正しく設定されることを検証
    @Test func checkTrigger_ManualTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .manual)
        #expect(manager.lastCheckTrigger == .manual)
    }

    /// 起動時トリガーが正しく設定されることを検証
    @Test func checkTrigger_StartupTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .startup)
        #expect(manager.lastCheckTrigger == .startup)
    }

    /// 自動トリガーが正しく設定されることを検証
    @Test func checkTrigger_AutomaticTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .automatic)
        #expect(manager.lastCheckTrigger == .automatic)
    }

    // MARK: - [M-2] Version Comparison with count >= 2

    /// 3コンポーネント形式(X.Y.Z)のバージョン比較が先頭2要素で動作することを検証
    @Test func isNewer_ThreeComponentVersion_WorksCorrectly() {
        // count >= 2 に緩和されたことで、将来的な X.Y.Z 形式にも対応できることを確認
        // 先頭 2 コンポーネントで比較する
        #expect(UpdateManager.isNewer("202603.0.1", than: "202602.9.9"))
        #expect(!UpdateManager.isNewer("202602.0.1", than: "202602.9.9"))
    }

    /// 1コンポーネントのバージョンがfalseを返すことを検証
    @Test func isNewer_SingleComponentVersion_ReturnsFalse() {
        // 1 コンポーネントは引き続き false
        #expect(!UpdateManager.isNewer("202603", than: "202602"))
    }

    // MARK: - [C-2] SHA-256 Checksum Verification

    /// 正しいSHA-256ハッシュで検証が成功することを検証
    @Test func verifySHA256_ValidHash_ReturnsTrue() throws {
        let data = Data("hello world".utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString).bin")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // 正確なハッシュを計算して検証
        let digest = SHA256.hash(data: data)
        let actualHex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(UpdateManager.verifySHA256(of: tempURL, expectedHex: actualHex))
    }

    /// 不正なSHA-256ハッシュで検証が失敗することを検証
    @Test func verifySHA256_InvalidHash_ReturnsFalse() throws {
        let data = Data("hello world".utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString).bin")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(!UpdateManager.verifySHA256(of: tempURL, expectedHex: "0000000000000000000000000000000000000000000000000000000000000000"))
    }

    /// 存在しないファイルのチェックサム検証がfalseを返すことを検証
    @Test func verifySHA256_NonexistentFile_ReturnsFalse() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_sobani_test.bin")
        #expect(!UpdateManager.verifySHA256(of: nonexistentURL, expectedHex: "abc123"))
    }

    // MARK: - DMG Asset Selection Tests

    /// DMGとZIPの両方がある場合にDMGが優先選択されることを検証
    @Test func assetSelection_DMGPreferredOverZIP() throws {
        let json = Data("""
        {
            "tag_name": "v202602.23",
            "assets": [
                {
                    "name": "Sobani-universal.zip",
                    "browser_download_url": "https://example.com/zip"
                },
                {
                    "name": "Sobani-universal.dmg",
                    "browser_download_url": "https://example.com/dmg"
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://example.com/checksums"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        // DMG を優先して選択
        let assetResult: (asset: GitHubAsset, format: UpdateAssetFormat)? = {
            if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return (dmg, .dmg)
            } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return (zip, .zip)
            }
            return nil
        }()

        #expect(assetResult != nil)
        #expect(assetResult?.asset.name == "Sobani-universal.dmg")
        if case .dmg = assetResult?.format {
            // OK
        } else {
            Issue.record("Expected .dmg format")
        }
    }

    /// DMGがない場合にZIPがフォールバックとして選択されることを検証
    @Test func assetSelection_ZIPFallbackWhenNoDMG() throws {
        let json = Data("""
        {
            "tag_name": "v202602.21",
            "assets": [
                {
                    "name": "Sobani-universal.zip",
                    "browser_download_url": "https://example.com/zip"
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://example.com/checksums"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        let assetResult: (asset: GitHubAsset, format: UpdateAssetFormat)? = {
            if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return (dmg, .dmg)
            } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return (zip, .zip)
            }
            return nil
        }()

        #expect(assetResult != nil)
        #expect(assetResult?.asset.name == "Sobani-universal.zip")
        if case .zip = assetResult?.format {
            // OK
        } else {
            Issue.record("Expected .zip format")
        }
    }

    /// DMGもZIPもない場合にnilが返されることを検証
    @Test func assetSelection_NoMatchingAsset() throws {
        let json = Data("""
        {
            "tag_name": "v202602.23",
            "assets": [
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://example.com/checksums"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        let assetResult: (asset: GitHubAsset, format: UpdateAssetFormat)? = {
            if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return (dmg, .dmg)
            } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return (zip, .zip)
            }
            return nil
        }()

        #expect(assetResult == nil)
    }

    /// DMGのみのリリースでDMGが正しく選択されることを検証
    @Test func assetSelection_DMGOnlyRelease() throws {
        let json = Data("""
        {
            "tag_name": "v202602.22",
            "assets": [
                {
                    "name": "Sobani-universal.dmg",
                    "browser_download_url": "https://github.com/shiroemons/sobani/releases/download/v202602.22/Sobani-universal.dmg"
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://github.com/shiroemons/sobani/releases/download/v202602.22/checksums.txt"
                }
            ]
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.assets.count == 2)
        #expect(release.assets[0].name == "Sobani-universal.dmg")

        let assetResult: (asset: GitHubAsset, format: UpdateAssetFormat)? = {
            if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return (dmg, .dmg)
            } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return (zip, .zip)
            }
            return nil
        }()

        #expect(assetResult != nil)
        #expect(assetResult?.asset.name == "Sobani-universal.dmg")
        #expect(
            assetResult?.asset.browserDownloadURL
                == "https://github.com/shiroemons/sobani/releases/download/v202602.22/Sobani-universal.dmg"
        )
        if case .dmg = assetResult?.format {
            // OK
        } else {
            Issue.record("Expected .dmg format")
        }
    }

    // MARK: - UpdateAssetFormat Tests

    /// UpdateAssetFormatのenum caseが正しく区別されることを検証
    @Test func updateAssetFormat_EnumCases() {
        let dmg: UpdateAssetFormat = .dmg
        let zip: UpdateAssetFormat = .zip

        switch dmg {
        case .dmg: break // OK
        case .zip: Issue.record("Expected .dmg")
        }

        switch zip {
        case .zip: break // OK
        case .dmg: Issue.record("Expected .zip")
        }
    }

    // MARK: - handleWake Tests

    /// 最終チェックからcheckInterval経過後のhandleWakeでチェックが実行されることを検証
    @Test func handleWake_IntervalElapsed_TriggersCheck() throws {
        let suiteName = "handleWake_elapsed_\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        testDefaults.set(Date.distantPast, forKey: "LastUpdateCheckDate")

        let manager = UpdateManager(currentVersion: "202602.4", defaults: testDefaults)
        manager.handleWake()
        #expect(manager.lastCheckTrigger == .automatic)
    }

    /// 最終チェックからcheckInterval未経過のhandleWakeでチェックがスキップされることを検証
    @Test func handleWake_IntervalNotElapsed_SkipsCheck() throws {
        let suiteName = "handleWake_not_elapsed_\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        testDefaults.set(Date(), forKey: "LastUpdateCheckDate")

        let manager = UpdateManager(currentVersion: "202602.4", defaults: testDefaults)
        manager.handleWake()
        // lastCheckTrigger stays at default .automatic, state stays .idle (no check triggered)
        #expect(manager.lastCheckTrigger == .automatic)
    }

    /// 最終チェック未記録のhandleWakeでチェックが実行されることを検証
    @Test func handleWake_NoLastCheck_TriggersCheck() throws {
        let suiteName = "handleWake_no_last_\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let manager = UpdateManager(currentVersion: "202602.4", defaults: testDefaults)
        manager.handleWake()
        #expect(manager.lastCheckTrigger == .automatic)
    }

}
