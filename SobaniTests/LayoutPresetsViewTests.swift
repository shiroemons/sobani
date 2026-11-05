import Foundation
import Testing
@testable import Sobani

/// 管理パネルのプリセット名入力の検証を検証するテスト
@Suite struct PresetNameValidationTests {

    /// 空・空白のみの名前は空として扱われ、重複判定は行われないことを検証
    @Test(arguments: ["", "   ", "\n\t"])
    func blankNameIsEmpty(input: String) throws {
        var checkedNames: [String] = []
        let result = PresetNameValidation.validate(input) { name in
            checkedNames.append(name)
            return false
        }
        #expect(result == .empty)
        #expect(result.validName == nil)
        #expect(checkedNames.isEmpty)
    }

    /// 前後の空白を除いた名前で重複判定され、そのまま確定に使われることを検証
    @Test func nameIsTrimmedBeforeCheck() throws {
        var checkedNames: [String] = []
        let result = PresetNameValidation.validate("  Work  ") { name in
            checkedNames.append(name)
            return false
        }
        #expect(result == .valid("Work"))
        #expect(result.validName == "Work")
        #expect(checkedNames == ["Work"])
    }

    /// 既存の名前と重複する場合は確定できないことを検証
    @Test func duplicateNameIsRejected() throws {
        let result = PresetNameValidation.validate("Home") { $0 == "Home" }
        #expect(result == .duplicate)
        #expect(result.validName == nil)
    }
}

/// レイアウトプリセット一覧の件数表示の書式を検証するテスト
@Suite struct LayoutPresetItemsCountTests {

    private func languageBundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    /// 英語では単数・複数で語形が変わることを検証（システムの言語に関係なく "1 items" にならない）
    @Test func englishUsesPluralForms() throws {
        let bundle = try languageBundle("en")
        #expect(LayoutPresetText.itemsCount(1, bundle: bundle) == "1 item")
        #expect(LayoutPresetText.itemsCount(3, bundle: bundle) == "3 items")
    }

    /// 日本語では件数に「件」が付くことを検証
    @Test func japaneseUsesCounter() throws {
        let bundle = try languageBundle("ja")
        #expect(LayoutPresetText.itemsCount(1, bundle: bundle) == "1件")
        #expect(LayoutPresetText.itemsCount(2, bundle: bundle) == "2件")
    }
}
