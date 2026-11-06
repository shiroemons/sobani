import Cocoa
import Testing
@testable import Sobani

@Suite("AppDelegate Tests")
struct AppDelegateTests {

    // MARK: - resolveImageName Tests

    @Test("resolveImageName: デフォルト画像名と一致する場合 → デフォルトを返す")
    func resolveImageNameDefault() {
        let result = AppDelegate.resolveImageName(
            "default", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: デフォルト画像名と一致する場合（登録画像あり） → デフォルトを返す")
    func resolveImageNameDefaultEvenIfRegistered() {
        let result = AppDelegate.resolveImageName(
            "default", defaultImageName: "default", registeredImageExists: true
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: 登録画像が存在する場合 → その名前を返す")
    func resolveImageNameRegistered() {
        let result = AppDelegate.resolveImageName(
            "custom.png", defaultImageName: "default", registeredImageExists: true
        )
        #expect(result.resolvedName == "custom.png")
        #expect(result.isDefault == false)
    }

    @Test("resolveImageName: 登録画像が存在しない場合 → デフォルトにフォールバック")
    func resolveImageNameFallback() {
        let result = AppDelegate.resolveImageName(
            "missing.png", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    @Test("resolveImageName: 空文字列で登録画像が存在しない場合 → デフォルトにフォールバック")
    func resolveImageNameEmptyString() {
        let result = AppDelegate.resolveImageName(
            "", defaultImageName: "default", registeredImageExists: false
        )
        #expect(result.resolvedName == "default")
        #expect(result.isDefault == true)
    }

    // MARK: - migrateWindowIds Tests

    @Test("migrateWindowIds: 全てのIDが有効な場合 → 割り当てなし")
    func migrateWindowIdsAllValid() {
        let result = AppDelegate.migrateWindowIds(existingIds: [1, 2, 3], legacyId: 0)
        #expect(result.assignments.isEmpty)
        #expect(result.nextId == 4)
    }

    @Test("migrateWindowIds: legacyIdを含む場合 → 新しいIDを割り当て")
    func migrateWindowIdsWithLegacy() {
        let result = AppDelegate.migrateWindowIds(existingIds: [1, 0, 3], legacyId: 0)
        #expect(result.assignments.count == 1)
        #expect(result.assignments[0].oldIndex == 1)
        #expect(result.assignments[0].newId == 4)
        #expect(result.nextId == 5)
    }

    @Test("migrateWindowIds: 空配列の場合 → 割り当てなし、nextId=1")
    func migrateWindowIdsEmpty() {
        let result = AppDelegate.migrateWindowIds(existingIds: [], legacyId: 0)
        #expect(result.assignments.isEmpty)
        #expect(result.nextId == 1)
    }

    @Test("migrateWindowIds: 全てlegacyIdの場合 → 全要素に新IDを割り当て")
    func migrateWindowIdsAllLegacy() {
        let result = AppDelegate.migrateWindowIds(existingIds: [0, 0, 0], legacyId: 0)
        #expect(result.assignments.count == 3)
        #expect(result.assignments[0] == (oldIndex: 0, newId: 1))
        #expect(result.assignments[1] == (oldIndex: 1, newId: 2))
        #expect(result.assignments[2] == (oldIndex: 2, newId: 3))
        #expect(result.nextId == 4)
    }

    @Test("migrateWindowIds: 連番でないIDの場合 → maxから連番を割り当て")
    func migrateWindowIdsNonSequential() {
        let result = AppDelegate.migrateWindowIds(existingIds: [5, 0, 10], legacyId: 0)
        #expect(result.assignments.count == 1)
        #expect(result.assignments[0].oldIndex == 1)
        #expect(result.assignments[0].newId == 11)
        #expect(result.nextId == 12)
    }
}

@Suite("AppDelegate Image Resolution Tests")
@MainActor
struct AppDelegateImageResolutionTests {
    let imageManager: ImageManager

    init() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        imageManager = ImageManager(baseDirectory: tempDirectory)
    }

    @Test("読み込める登録画像はキャッシュ済みの画像と登録名で表示する")
    func resolvedImageUsesCachedRegisteredImage() throws {
        let source = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let name = try #require(imageManager.registerImage(source, name: "sample.png"))

        let resolved = AppDelegate.resolvedImage(named: name, in: imageManager)

        #expect(resolved.displayName == name)
        #expect(resolved.image === imageManager.image(named: name))
    }

    @Test("読み込めない画像名はデフォルト画像と既定の表示名にフォールバックする")
    func resolvedImageFallsBackToDefault() {
        let resolved = AppDelegate.resolvedImage(named: "missing.png", in: imageManager)

        #expect(resolved.displayName == AppConstants.defaultImageName)
        #expect(resolved.image === imageManager.defaultImage())
    }
}

@Suite("SliderMenuItemFactory Tests")
@MainActor
struct SliderMenuItemFactoryTests {
    private final class Target: NSObject {
        @objc func changed(_ sender: NSSlider) {}
    }

    @Test("2 行のスライダー項目でスライダーと % 表示を取得・更新できる（スライダーの tag はウィンドウ番号のまま）")
    func twoRowItemLookupAndUpdate() throws {
        let target = Target()
        // % 表示ラベルの識別タグと同じ値をスライダーの tag（ウィンドウ番号）に入れても取り違えない
        let item = SliderMenuItemFactory.makeTwoRowItem(
            iconSymbol: AppConstants.opacitySymbol,
            text: "label",
            slider: SliderMenuItemFactory.SliderSpec(
                value: 0.5, range: 0...1, target: target, action: #selector(Target.changed(_:)), tag: 1
            )
        )
        let container = try #require(item.view)
        let slider = try #require(SliderMenuItemFactory.slider(in: container))
        let percentLabel = try #require(SliderMenuItemFactory.percentLabel(in: container))
        #expect(slider.tag == 1)
        #expect(percentLabel.stringValue == FormatUtils.formatOpacity(0.5))

        SliderMenuItemFactory.update(container, value: 0.8)
        #expect(abs(slider.doubleValue - 0.8) < AppConstants.floatingPointTolerance)
        #expect(percentLabel.stringValue == FormatUtils.formatOpacity(0.8))
    }

    @Test("スライダーを無効にすると % 表示が薄くなり、有効に戻すと元に戻る")
    func setSliderEnabledDimsPercentLabel() throws {
        let target = Target()
        let item = SliderMenuItemFactory.makeSingleRowItem(
            iconSymbol: AppConstants.ghostModeSymbol,
            text: "label",
            slider: SliderMenuItemFactory.SliderSpec(
                value: 0.3, range: 0...1, target: target, action: #selector(Target.changed(_:))
            )
        )
        let container = try #require(item.view)
        let slider = try #require(SliderMenuItemFactory.slider(in: container))
        let percentLabel = try #require(SliderMenuItemFactory.percentLabel(in: container))

        SliderMenuItemFactory.setSliderEnabled(false, in: container)
        #expect(!slider.isEnabled)
        #expect(percentLabel.alphaValue < 1.0)

        SliderMenuItemFactory.setSliderEnabled(true, in: container)
        #expect(slider.isEnabled)
        #expect(abs(percentLabel.alphaValue - 1.0) < AppConstants.floatingPointTolerance)
    }
}
