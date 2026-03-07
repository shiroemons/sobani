import XCTest
@testable import Sobani

/// 画像の登録・読み込み・削除、カスタムデフォルト画像の管理、サポート形式のフィルタリング、パストラバーサル防止を検証するテスト
final class ImageManagerTests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    var tempDirectory: URL!
    // swiftlint:disable:next implicitly_unwrapped_optional
    var imageManager: ImageManager!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        imageManager = ImageManager(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        imageManager = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func createTestPNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    @discardableResult
    private func createTestImageFile(named name: String, in directory: URL? = nil) throws -> URL {
        let dir = try XCTUnwrap(directory ?? tempDirectory)
        let url = dir.appendingPathComponent(name)
        let data = try createTestPNGData()
        try data.write(to: url)
        return url
    }

    private func createSourceDirectory() throws -> URL {
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTestsSource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        return sourceDir
    }

    // MARK: - registeredImageNames Tests

    /// 空ディレクトリで空配列が返されることを検証
    func testRegisteredImageNames_EmptyDirectory() {
        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, [])
    }

    /// サポート外の拡張子がフィルタリングされることを検証
    func testRegisteredImageNames_FiltersUnsupportedExtensions() throws {
        let imagesDir = tempDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        try createTestImageFile(named: "test.png", in: imagesDir)
        try createTestImageFile(named: "test.jpg", in: imagesDir)
        try "not an image".write(to: imagesDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try "not an image".write(to: imagesDir.appendingPathComponent("test.pdf"), atomically: true, encoding: .utf8)

        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, ["test.jpg", "test.png"])
    }

    /// 画像名がアルファベット順にソートされることを検証
    func testRegisteredImageNames_SortedAlphabetically() throws {
        let imagesDir = tempDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        try createTestImageFile(named: "charlie.png", in: imagesDir)
        try createTestImageFile(named: "alpha.png", in: imagesDir)
        try createTestImageFile(named: "bravo.png", in: imagesDir)

        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, ["alpha.png", "bravo.png", "charlie.png"])
    }

    // MARK: - registerImage Tests

    /// 画像ファイルがimagesディレクトリにコピーされることを検証
    func testRegisterImage_CopiesFile() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "myimage.png", in: sourceDir)

        let savedName = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(savedName, "myimage.png")

        let names = imageManager.registeredImageNames()
        XCTAssertTrue(names.contains("myimage.png"))
    }

    /// 重複ファイル名に連番サフィックスが付与されることを検証
    func testRegisterImage_UniqueNaming() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "duplicate.png", in: sourceDir)

        let name1 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name1, "duplicate.png")

        let name2 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name2, "duplicate_1.png")

        let name3 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name3, "duplicate_2.png")
    }

    // MARK: - removeRegisteredImage Tests

    /// 登録済み画像が正しく削除されることを検証
    func testRemoveRegisteredImage_DeletesFile() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "todelete.png", in: sourceDir)
        imageManager.registerImage(from: sourceURL)

        XCTAssertTrue(imageManager.registeredImageNames().contains("todelete.png"))

        imageManager.removeRegisteredImage(named: "todelete.png")

        XCTAssertFalse(imageManager.registeredImageNames().contains("todelete.png"))
    }

    // MARK: - loadRegisteredImage Tests

    /// 登録済み画像が正しく読み込まれることを検証
    func testLoadRegisteredImage_ReturnsImage() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "loadme.png", in: sourceDir)
        imageManager.registerImage(from: sourceURL)

        let image = imageManager.loadRegisteredImage(named: "loadme.png")
        XCTAssertNotNil(image)
    }

    /// 存在しない画像名でnilが返されることを検証
    func testLoadRegisteredImage_NonExistent_ReturnsNil() {
        let image = imageManager.loadRegisteredImage(named: "nonexistent.png")
        XCTAssertNil(image)
    }

    // MARK: - Custom Default Tests

    /// カスタムデフォルト画像が正しく設定されることを検証
    func testSetCustomDefault_CreatesFile() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "default.png", in: sourceDir)

        XCTAssertFalse(imageManager.hasCustomDefault)

        imageManager.setCustomDefault(from: sourceURL)

        XCTAssertTrue(imageManager.hasCustomDefault)

        let defaultURL = tempDirectory.appendingPathComponent("default.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: defaultURL.path))
    }

    /// カスタムデフォルト画像がリセットされることを検証
    func testResetCustomDefault_RemovesFile() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "default.png", in: sourceDir)
        imageManager.setCustomDefault(from: sourceURL)

        XCTAssertTrue(imageManager.hasCustomDefault)

        imageManager.resetCustomDefault()

        XCTAssertFalse(imageManager.hasCustomDefault)
    }

    // MARK: - registerImage Extension Guard Tests

    /// 外部パスからの画像登録でコピーと名前返却が正しく動作することを検証
    func testRegisterImage_FromExternalPath_CopiesAndReturnsName() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "external.png", in: sourceDir)

        let savedName = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(savedName, "external.png")

        let names = imageManager.registeredImageNames()
        XCTAssertTrue(names.contains("external.png"))
    }

    /// 異なるソースからの同名画像に一意な名前が付与されることを検証
    func testRegisterImage_DuplicateFromDifferentSource_GetsUniqueName() throws {
        let sourceDir1 = try createSourceDirectory()
        let sourceDir2 = try createSourceDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceDir1)
            try? FileManager.default.removeItem(at: sourceDir2)
        }

        let sourceURL1 = try createTestImageFile(named: "photo.png", in: sourceDir1)
        let sourceURL2 = try createTestImageFile(named: "photo.png", in: sourceDir2)

        let name1 = imageManager.registerImage(from: sourceURL1)
        XCTAssertEqual(name1, "photo.png")

        let name2 = imageManager.registerImage(from: sourceURL2)
        XCTAssertEqual(name2, "photo_1.png")
    }

    /// サポート外の拡張子でnilが返され登録されないことを検証
    func testRegisterImage_UnsupportedExtension_ReturnsNil() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        // Create files with unsupported extensions
        let txtURL = sourceDir.appendingPathComponent("document.txt")
        try "not an image".write(to: txtURL, atomically: true, encoding: .utf8)

        let pdfURL = sourceDir.appendingPathComponent("document.pdf")
        try "not an image".write(to: pdfURL, atomically: true, encoding: .utf8)

        let svgURL = sourceDir.appendingPathComponent("image.svg")
        try "<svg></svg>".write(to: svgURL, atomically: true, encoding: .utf8)

        XCTAssertNil(imageManager.registerImage(from: txtURL))
        XCTAssertNil(imageManager.registerImage(from: pdfURL))
        XCTAssertNil(imageManager.registerImage(from: svgURL))

        // Verify nothing was registered
        XCTAssertEqual(imageManager.registeredImageNames(), [])
    }

    // MARK: - Custom Default Tests

    /// hasCustomDefaultの状態遷移が正しいことを検証
    func testHasCustomDefault_Correctness() throws {
        XCTAssertFalse(imageManager.hasCustomDefault)

        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "default.png", in: sourceDir)
        imageManager.setCustomDefault(from: sourceURL)
        XCTAssertTrue(imageManager.hasCustomDefault)

        imageManager.resetCustomDefault()
        XCTAssertFalse(imageManager.hasCustomDefault)
    }

    // MARK: - [H-3] Path Traversal Prevention Tests

    /// パストラバーサルを含む画像名でnilが返されることを検証
    func testLoadRegisteredImage_PathTraversal_ReturnsNil() {
        // "../" を含む名前では nil を返すことを確認
        XCTAssertNil(imageManager.loadRegisteredImage(named: "../secret.png"))
        XCTAssertNil(imageManager.loadRegisteredImage(named: "../../etc/passwd"))
        XCTAssertNil(imageManager.loadRegisteredImage(named: "/etc/passwd"))
        XCTAssertNil(imageManager.loadRegisteredImage(named: ""))
        XCTAssertNil(imageManager.loadRegisteredImage(named: "."))
    }

    /// パストラバーサルでimagesディレクトリ外のファイルが削除されないことを検証
    func testRemoveRegisteredImage_PathTraversal_DoesNotDeleteOutsideDir() throws {
        // imagesDir の外にファイルを作成し、パストラバーサルで削除されないことを確認
        let outsideDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTestsOutside-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideDir) }

        let targetFile = outsideDir.appendingPathComponent("should_not_be_deleted.png")
        try? createTestPNGData().write(to: targetFile)

        // パストラバーサルを試みる
        imageManager.removeRegisteredImage(named: "../SobaniTestsOutside-\(outsideDir.lastPathComponent)/should_not_be_deleted.png")

        // ファイルは削除されていないことを確認
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
    }

    /// パストラバーサル防止後も正常なファイル名で画像が読み込めることを検証
    func testLoadRegisteredImage_ValidName_ReturnsImage() throws {
        // 正常なファイル名は引き続き動作することを確認
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = try createTestImageFile(named: "valid.png", in: sourceDir)
        imageManager.registerImage(from: sourceURL)

        let image = imageManager.loadRegisteredImage(named: "valid.png")
        XCTAssertNotNil(image)
    }

    // MARK: - Copy Failure Tests

    /// 存在しないソースからの登録でnilが返されることを検証
    func testRegisterImage_CopyFailure_ReturnsNil() {
        // 存在しないソースからのコピーは nil を返すことを確認
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent_sobani_test.png")
        let result = imageManager.registerImage(from: nonexistentURL)
        XCTAssertNil(result)
    }

    // MARK: - supportedExtensions Tests

    /// supportedExtensionsが全サポート形式を含むことを検証
    func testSupportedExtensions_containsAllFormats() {
        let expected = Set(["png", "jpg", "jpeg", "gif", "tiff", "heic"])
        XCTAssertEqual(Set(ImageManager.supportedExtensions), expected)
    }
}
