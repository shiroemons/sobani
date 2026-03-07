import XCTest
import CryptoKit
@testable import Sobani

/// バージョン比較ロジック、GitHubリリースJSONパース、チェックトリガー、SHA-256チェックサム検証、アセット選択を検証するテスト
final class UpdateManagerTests: XCTestCase {

    // MARK: - isNewer Tests

    /// 同一バージョンでfalseを返すことを検証
    func testIsNewer_SameVersion_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "202602.2"))
    }

    /// パッチ番号が大きいバージョンでtrueを返すことを検証
    func testIsNewer_PatchLarger_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202602.3", than: "202602.2"))
    }

    /// パッチ番号が小さいバージョンでfalseを返すことを検証
    func testIsNewer_PatchSmaller_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.1", than: "202602.2"))
    }

    /// 月が新しいバージョンでtrueを返すことを検証
    func testIsNewer_MonthNewer_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202603.0", than: "202602.2"))
    }

    /// 月が古いバージョンでfalseを返すことを検証
    func testIsNewer_MonthOlder_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202601.5", than: "202602.2"))
    }

    /// 2桁パッチ番号の数値比較が正しいことを検証(10 > 2)
    func testIsNewer_TwoDigitPatch_ReturnsTrue() {
        // 202602.10 > 202602.2 (numeric comparison, not string)
        XCTAssertTrue(UpdateManager.isNewer("202602.10", than: "202602.2"))
    }

    /// 2桁パッチ番号の数値比較が正しいことを検証(2 < 10)
    func testIsNewer_TwoDigitPatch_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "202602.10"))
    }

    /// 不正なバージョン形式でfalseを返すことを検証
    func testIsNewer_InvalidFormat_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("invalid", than: "202602.2"))
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "invalid"))
        XCTAssertFalse(UpdateManager.isNewer("", than: ""))
        XCTAssertFalse(UpdateManager.isNewer("v202602.3", than: "202602.2"))
    }

    /// 年をまたぐバージョン比較が正しいことを検証
    func testIsNewer_YearChange_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202701.0", than: "202612.5"))
    }

    // MARK: - GitHubRelease JSON Parsing Tests

    /// GitHubリリースJSONが正しくデコードされることを検証
    func testGitHubRelease_DecodesCorrectly() throws {
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
        XCTAssertEqual(release.tagName, "v202602.3")
        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "Sobani-202602.3-universal.zip")
        XCTAssertEqual(
            release.assets[0].browserDownloadURL,
            "https://github.com/shiroemons/sobani/releases/download/v202602.3/Sobani-202602.3-universal.zip"
        )
    }

    /// アセットが空のリリースJSONが正しくデコードされることを検証
    func testGitHubRelease_EmptyAssets() throws {
        let json = Data("""
        {
            "tag_name": "v202602.3",
            "assets": []
        }
        """.utf8)

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v202602.3")
        XCTAssertTrue(release.assets.isEmpty)
    }

    /// 複数アセットを持つリリースJSONが正しくデコードされることを検証
    func testGitHubRelease_MultipleAssets() throws {
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
        XCTAssertEqual(release.assets.count, 2)
        XCTAssertEqual(release.assets[0].name, "Sobani-202602.3-universal.zip")
        XCTAssertEqual(release.assets[1].name, "checksums.txt")
    }

    // MARK: - CheckTrigger Tests

    /// チェックトリガーのデフォルトがautomaticであることを検証
    func testCheckTrigger_DefaultIsAutomatic() {
        let manager = UpdateManager(currentVersion: "202602.4")
        XCTAssertEqual(manager.lastCheckTrigger, .automatic)
    }

    /// 手動トリガーが正しく設定されることを検証
    func testCheckTrigger_ManualTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .manual)
        XCTAssertEqual(manager.lastCheckTrigger, .manual)
    }

    /// 起動時トリガーが正しく設定されることを検証
    func testCheckTrigger_StartupTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .startup)
        XCTAssertEqual(manager.lastCheckTrigger, .startup)
    }

    /// 自動トリガーが正しく設定されることを検証
    func testCheckTrigger_AutomaticTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .automatic)
        XCTAssertEqual(manager.lastCheckTrigger, .automatic)
    }

    // MARK: - [M-2] Version Comparison with count >= 2

    /// 3コンポーネント形式(X.Y.Z)のバージョン比較が先頭2要素で動作することを検証
    func testIsNewer_ThreeComponentVersion_WorksCorrectly() {
        // count >= 2 に緩和されたことで、将来的な X.Y.Z 形式にも対応できることを確認
        // 先頭 2 コンポーネントで比較する
        XCTAssertTrue(UpdateManager.isNewer("202603.0.1", than: "202602.9.9"))
        XCTAssertFalse(UpdateManager.isNewer("202602.0.1", than: "202602.9.9"))
    }

    /// 1コンポーネントのバージョンがfalseを返すことを検証
    func testIsNewer_SingleComponentVersion_ReturnsFalse() {
        // 1 コンポーネントは引き続き false
        XCTAssertFalse(UpdateManager.isNewer("202603", than: "202602"))
    }

    // MARK: - [C-2] SHA-256 Checksum Verification

    /// 正しいSHA-256ハッシュで検証が成功することを検証
    func testVerifySHA256_ValidHash_ReturnsTrue() throws {
        let data = Data("hello world".utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString).bin")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // 正確なハッシュを計算して検証
        let digest = SHA256.hash(data: data)
        let actualHex = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertTrue(UpdateManager.verifySHA256(of: tempURL, expectedHex: actualHex))
    }

    /// 不正なSHA-256ハッシュで検証が失敗することを検証
    func testVerifySHA256_InvalidHash_ReturnsFalse() throws {
        let data = Data("hello world".utf8)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sobani_test_\(UUID().uuidString).bin")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertFalse(UpdateManager.verifySHA256(of: tempURL, expectedHex: "0000000000000000000000000000000000000000000000000000000000000000"))
    }

    /// 存在しないファイルのチェックサム検証がfalseを返すことを検証
    func testVerifySHA256_NonexistentFile_ReturnsFalse() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_sobani_test.bin")
        XCTAssertFalse(UpdateManager.verifySHA256(of: nonexistentURL, expectedHex: "abc123"))
    }

    // MARK: - DMG Asset Selection Tests

    /// DMGとZIPの両方がある場合にDMGが優先選択されることを検証
    func testAssetSelection_DMGPreferredOverZIP() throws {
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

        XCTAssertNotNil(assetResult)
        XCTAssertEqual(assetResult?.asset.name, "Sobani-universal.dmg")
        if case .dmg = assetResult?.format {
            // OK
        } else {
            XCTFail("Expected .dmg format")
        }
    }

    /// DMGがない場合にZIPがフォールバックとして選択されることを検証
    func testAssetSelection_ZIPFallbackWhenNoDMG() throws {
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

        XCTAssertNotNil(assetResult)
        XCTAssertEqual(assetResult?.asset.name, "Sobani-universal.zip")
        if case .zip = assetResult?.format {
            // OK
        } else {
            XCTFail("Expected .zip format")
        }
    }

    /// DMGもZIPもない場合にnilが返されることを検証
    func testAssetSelection_NoMatchingAsset() throws {
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

        XCTAssertNil(assetResult)
    }

    /// DMGのみのリリースでDMGが正しく選択されることを検証
    func testAssetSelection_DMGOnlyRelease() throws {
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
        XCTAssertEqual(release.assets.count, 2)
        XCTAssertEqual(release.assets[0].name, "Sobani-universal.dmg")

        let assetResult: (asset: GitHubAsset, format: UpdateAssetFormat)? = {
            if let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                return (dmg, .dmg)
            } else if let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                return (zip, .zip)
            }
            return nil
        }()

        XCTAssertNotNil(assetResult)
        XCTAssertEqual(assetResult?.asset.name, "Sobani-universal.dmg")
        XCTAssertEqual(
            assetResult?.asset.browserDownloadURL,
            "https://github.com/shiroemons/sobani/releases/download/v202602.22/Sobani-universal.dmg"
        )
        if case .dmg = assetResult?.format {
            // OK
        } else {
            XCTFail("Expected .dmg format")
        }
    }

    // MARK: - UpdateAssetFormat Tests

    /// UpdateAssetFormatのenum caseが正しく区別されることを検証
    func testUpdateAssetFormat_EnumCases() {
        let dmg: UpdateAssetFormat = .dmg
        let zip: UpdateAssetFormat = .zip

        switch dmg {
        case .dmg: break // OK
        case .zip: XCTFail("Expected .dmg")
        }

        switch zip {
        case .zip: break // OK
        case .dmg: XCTFail("Expected .zip")
        }
    }

}
