import AppKit
import Foundation
import Testing

@testable import Sobani

@Suite @MainActor struct ImageManagerRegressionTests {
    let tempDirectory: URL
    let imageManager: ImageManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniRegressionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
        imageManager = ImageManager(baseDirectory: tempDirectory)
    }

    private func createSourceDirectory() throws -> URL {
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniRegressionSource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        return sourceDir
    }

    private func createTestPNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        let tiffData = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        return image
    }

    @Test func registerImage_InvalidImageData_ReturnsNil() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let url = sourceDir.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: url)

        let result = imageManager.registerImage(from: url)

        #expect(result == nil)
        #expect(!imageManager.registeredImageNames().contains("broken.png"))
    }

    @Test func registerImage_NSImage_UniqueNaming() {
        let image = createTestImage()

        let first = imageManager.registerImage(image, name: "direct_duplicate.png")
        let second = imageManager.registerImage(image, name: "direct_duplicate.png")

        #expect(first == "direct_duplicate.png")
        #expect(second == "direct_duplicate_1.png")
        #expect(imageManager.registeredImageNames().contains("direct_duplicate.png"))
        #expect(imageManager.registeredImageNames().contains("direct_duplicate_1.png"))
    }

    @Test func setCustomDefault_CopyFailure_PreservesExistingFile() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let sourceURL = sourceDir.appendingPathComponent("default.png")
        try createTestPNGData().write(to: sourceURL)
        imageManager.setCustomDefault(from: sourceURL)
        let defaultURL = try #require(imageManager.customDefaultURL)
        let originalData = try Data(contentsOf: defaultURL)

        let missingURL = sourceDir.appendingPathComponent("missing.png")
        imageManager.setCustomDefault(from: missingURL)

        #expect(imageManager.hasCustomDefault)
        #expect(try Data(contentsOf: defaultURL) == originalData)
    }
}
