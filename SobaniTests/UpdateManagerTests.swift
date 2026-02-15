import XCTest
@testable import Sobani

final class UpdateManagerTests: XCTestCase {

    // MARK: - isNewer Tests

    func testIsNewer_SameVersion_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "202602.2"))
    }

    func testIsNewer_PatchLarger_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202602.3", than: "202602.2"))
    }

    func testIsNewer_PatchSmaller_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.1", than: "202602.2"))
    }

    func testIsNewer_MonthNewer_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202603.0", than: "202602.2"))
    }

    func testIsNewer_MonthOlder_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202601.5", than: "202602.2"))
    }

    func testIsNewer_TwoDigitPatch_ReturnsTrue() {
        // 202602.10 > 202602.2 (numeric comparison, not string)
        XCTAssertTrue(UpdateManager.isNewer("202602.10", than: "202602.2"))
    }

    func testIsNewer_TwoDigitPatch_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "202602.10"))
    }

    func testIsNewer_InvalidFormat_ReturnsFalse() {
        XCTAssertFalse(UpdateManager.isNewer("invalid", than: "202602.2"))
        XCTAssertFalse(UpdateManager.isNewer("202602.2", than: "invalid"))
        XCTAssertFalse(UpdateManager.isNewer("", than: ""))
        XCTAssertFalse(UpdateManager.isNewer("v202602.3", than: "202602.2"))
    }

    func testIsNewer_YearChange_ReturnsTrue() {
        XCTAssertTrue(UpdateManager.isNewer("202701.0", than: "202612.5"))
    }

    // MARK: - GitHubRelease JSON Parsing Tests

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

    func testCheckTrigger_DefaultIsAutomatic() {
        let manager = UpdateManager(currentVersion: "202602.4")
        XCTAssertEqual(manager.lastCheckTrigger, .automatic)
    }

    func testCheckTrigger_ManualTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .manual)
        XCTAssertEqual(manager.lastCheckTrigger, .manual)
    }

    func testCheckTrigger_StartupTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .startup)
        XCTAssertEqual(manager.lastCheckTrigger, .startup)
    }

    func testCheckTrigger_AutomaticTriggerIsSet() {
        let manager = UpdateManager(currentVersion: "202602.4")
        manager.checkForUpdate(trigger: .automatic)
        XCTAssertEqual(manager.lastCheckTrigger, .automatic)
    }
}
