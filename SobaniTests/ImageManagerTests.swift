import XCTest
@testable import Sobani

final class ImageManagerTests: XCTestCase {
    var tempDirectory: URL!
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

    private func createTestPNGData() -> Data {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Failed to create test PNG data")
        }
        return pngData
    }

    @discardableResult
    private func createTestImageFile(named name: String, in directory: URL? = nil) -> URL {
        let dir = directory ?? tempDirectory!
        let url = dir.appendingPathComponent(name)
        let data = createTestPNGData()
        try! data.write(to: url)
        return url
    }

    private func createSourceDirectory() -> URL {
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTestsSource-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        return sourceDir
    }

    // MARK: - registeredImageNames Tests

    func testRegisteredImageNames_EmptyDirectory() {
        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, [])
    }

    func testRegisteredImageNames_FiltersUnsupportedExtensions() {
        let imagesDir = tempDirectory.appendingPathComponent("images")
        try! FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        createTestImageFile(named: "test.png", in: imagesDir)
        createTestImageFile(named: "test.jpg", in: imagesDir)
        try! "not an image".write(to: imagesDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try! "not an image".write(to: imagesDir.appendingPathComponent("test.pdf"), atomically: true, encoding: .utf8)

        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, ["test.jpg", "test.png"])
    }

    func testRegisteredImageNames_SortedAlphabetically() {
        let imagesDir = tempDirectory.appendingPathComponent("images")
        try! FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        createTestImageFile(named: "charlie.png", in: imagesDir)
        createTestImageFile(named: "alpha.png", in: imagesDir)
        createTestImageFile(named: "bravo.png", in: imagesDir)

        let names = imageManager.registeredImageNames()
        XCTAssertEqual(names, ["alpha.png", "bravo.png", "charlie.png"])
    }

    // MARK: - registerImage Tests

    func testRegisterImage_CopiesFile() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "myimage.png", in: sourceDir)

        let savedName = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(savedName, "myimage.png")

        let names = imageManager.registeredImageNames()
        XCTAssertTrue(names.contains("myimage.png"))
    }

    func testRegisterImage_UniqueNaming() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "duplicate.png", in: sourceDir)

        let name1 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name1, "duplicate.png")

        let name2 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name2, "duplicate_1.png")

        let name3 = imageManager.registerImage(from: sourceURL)
        XCTAssertEqual(name3, "duplicate_2.png")
    }

    // MARK: - removeRegisteredImage Tests

    func testRemoveRegisteredImage_DeletesFile() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "todelete.png", in: sourceDir)
        imageManager.registerImage(from: sourceURL)

        XCTAssertTrue(imageManager.registeredImageNames().contains("todelete.png"))

        imageManager.removeRegisteredImage(named: "todelete.png")

        XCTAssertFalse(imageManager.registeredImageNames().contains("todelete.png"))
    }

    // MARK: - loadRegisteredImage Tests

    func testLoadRegisteredImage_ReturnsImage() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "loadme.png", in: sourceDir)
        imageManager.registerImage(from: sourceURL)

        let image = imageManager.loadRegisteredImage(named: "loadme.png")
        XCTAssertNotNil(image)
    }

    func testLoadRegisteredImage_NonExistent_ReturnsNil() {
        let image = imageManager.loadRegisteredImage(named: "nonexistent.png")
        XCTAssertNil(image)
    }

    // MARK: - Custom Default Tests

    func testSetCustomDefault_CreatesFile() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "default.png", in: sourceDir)

        XCTAssertFalse(imageManager.hasCustomDefault)

        imageManager.setCustomDefault(from: sourceURL)

        XCTAssertTrue(imageManager.hasCustomDefault)

        let defaultURL = tempDirectory.appendingPathComponent("default.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: defaultURL.path))
    }

    func testResetCustomDefault_RemovesFile() {
        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "default.png", in: sourceDir)
        imageManager.setCustomDefault(from: sourceURL)

        XCTAssertTrue(imageManager.hasCustomDefault)

        imageManager.resetCustomDefault()

        XCTAssertFalse(imageManager.hasCustomDefault)
    }

    func testHasCustomDefault_Correctness() {
        XCTAssertFalse(imageManager.hasCustomDefault)

        let sourceDir = createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = createTestImageFile(named: "default.png", in: sourceDir)
        imageManager.setCustomDefault(from: sourceURL)
        XCTAssertTrue(imageManager.hasCustomDefault)

        imageManager.resetCustomDefault()
        XCTAssertFalse(imageManager.hasCustomDefault)
    }
}
