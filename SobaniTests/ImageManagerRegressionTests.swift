import AppKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

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

    // MARK: - Validation

    private func createPNGData(width: Int, height: Int) throws -> Data {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        return try #require(rep.representation(using: .png, properties: [:]))
    }

    /// 縦横・総ピクセル数の上限判定を検証
    @Test func isAcceptableImageSizeBoundaries() {
        let maxSide = AppConstants.maxImagePixelDimension
        #expect(ImageManager.isAcceptableImageSize(width: 1, height: 1))
        #expect(ImageManager.isAcceptableImageSize(width: maxSide, height: AppConstants.maxImagePixelCount / maxSide))
        #expect(!ImageManager.isAcceptableImageSize(width: maxSide + 1, height: 1))
        #expect(!ImageManager.isAcceptableImageSize(width: 1, height: maxSide + 1))
        #expect(!ImageManager.isAcceptableImageSize(width: maxSide, height: maxSide))
        #expect(!ImageManager.isAcceptableImageSize(width: 0, height: 1))
    }

    /// 寸法が上限を超える画像は登録されないことを検証
    @Test func registerImage_OversizedImage_ReturnsNil() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let url = sourceDir.appendingPathComponent("tall.png")
        try createPNGData(width: 1, height: AppConstants.maxImagePixelDimension + 1).write(to: url)

        #expect(ImageManager.isValidImageFile(at: url) == false)
        #expect(imageManager.registerImage(from: url) == nil)
        #expect(imageManager.registeredImageNames().isEmpty)
    }

    /// シンボリックリンク経由の登録でリンクではなく実体がコピーされることを検証
    @Test func registerImage_Symlink_CopiesTarget() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let targetURL = sourceDir.appendingPathComponent("target.png")
        let pngData = try createTestPNGData()
        try pngData.write(to: targetURL)
        let linkURL = sourceDir.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let savedName = try #require(imageManager.registerImage(from: linkURL))

        #expect(savedName == "link.png")
        let savedURL = tempDirectory.appendingPathComponent("images").appendingPathComponent(savedName)
        let attributes = try FileManager.default.attributesOfItem(atPath: savedURL.path)
        #expect(attributes[.type] as? FileAttributeType == .typeRegular)
        #expect(try Data(contentsOf: savedURL) == pngData)
    }

    /// カスタムデフォルトに画像以外・非対応拡張子を指定しても設定されないことを検証
    @Test(arguments: ["fake.png", "image.txt"])
    func setCustomDefault_InvalidFile_ReturnsFalse(fileName: String) throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let url = sourceDir.appendingPathComponent(fileName)
        if fileName.hasSuffix(".png") {
            try Data("not an image".utf8).write(to: url)
        } else {
            try createTestPNGData().write(to: url)
        }

        #expect(!imageManager.setCustomDefault(from: url))
        #expect(!imageManager.hasCustomDefault)
    }

    /// 正常な画像でカスタムデフォルトの設定が成功を返すことを検証
    @Test func setCustomDefault_ValidImage_ReturnsTrue() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let url = sourceDir.appendingPathComponent("default.png")
        try createTestPNGData().write(to: url)

        #expect(imageManager.setCustomDefault(from: url))
        #expect(imageManager.hasCustomDefault)
    }

    // MARK: - registerImage(NSImage)

    /// NSImage登録で拡張子が.pngに揃えられ、PNGデータとして保存されることを検証
    @Test func registerImage_NSImage_ForcesPNGExtension() throws {
        let savedName = try #require(imageManager.registerImage(createTestImage(), name: "photo.jpg"))

        #expect(savedName == "photo.png")
        let savedURL = tempDirectory.appendingPathComponent("images").appendingPathComponent(savedName)
        let source = try #require(CGImageSourceCreateWithURL(savedURL as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
    }

    /// エンコード済みPNGデータの登録でも拡張子が.pngに揃い、重複名はリネームされることを検証
    @Test func registerPNGData_ForcesPNGExtensionAndUniqueName() throws {
        let cgImage = try #require(createTestImage().cgImage(forProposedRect: nil, context: nil, hints: nil))
        let pngData = try #require(ImageManager.pngData(from: cgImage))

        let first = imageManager.registerPNGData(pngData, name: "photo_nobg.jpg")
        let second = imageManager.registerPNGData(pngData, name: "photo_nobg.jpg")

        #expect(first == "photo_nobg.png")
        #expect(second == "photo_nobg_1.png")
        #expect(imageManager.registeredImageNames().contains("photo_nobg_1.png"))
        let savedURL = tempDirectory.appendingPathComponent("images").appendingPathComponent("photo_nobg.png")
        let source = try #require(CGImageSourceCreateWithURL(savedURL as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
        let saved = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(saved.width == cgImage.width)
        #expect(saved.height == cgImage.height)
    }

    /// pngFileNameが最終要素の拡張子を.pngに置き換えることを検証
    @Test(arguments: [
        ("photo.jpg", "photo.png"), ("a_nobg.png", "a_nobg.png"), ("noext", "noext.png"),
        ("dir/sub.tiff", "sub.png"), (".hidden", ".hidden.png"),
    ])
    func pngFileName_ReplacesExtension(name: String, expected: String) {
        #expect(ImageManager.pngFileName(for: name) == expected)
    }

    @Test(arguments: ["", ".", "..", "a/.."])
    func pngFileName_RejectsInvalidName(name: String) {
        #expect(ImageManager.pngFileName(for: name) == nil)
    }

    // MARK: - Cache

    /// パス付きの名前でもサニタイズ後のファイル名でキャッシュされ、削除で無効化されることを検証
    @Test func imageCache_UsesSanitizedNameAsKey() throws {
        let sourceDir = try createSourceDirectory()
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let url = sourceDir.appendingPathComponent("cached.png")
        try createTestPNGData().write(to: url)
        imageManager.registerImage(from: url)

        let viaPath = try #require(imageManager.loadRegisteredImageCached(named: "sub/cached.png"))
        let viaName = try #require(imageManager.loadRegisteredImageCached(named: "cached.png"))
        #expect(viaPath === viaName)

        imageManager.removeRegisteredImage(named: "cached.png")
        #expect(imageManager.loadRegisteredImageCached(named: "sub/cached.png") == nil)
    }
}
