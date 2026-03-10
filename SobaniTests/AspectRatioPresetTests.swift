import Foundation
import Testing
@testable import Sobani

@Suite struct AspectRatioPresetTests {

    @Test func free_ratioIsNil() {
        #expect(AspectRatioPreset.free.ratio == nil)
    }

    @Test func original_ratioIsNil() {
        #expect(AspectRatioPreset.original.ratio == nil)
    }

    @Test func square_ratioIsOne() throws {
        let ratio = try #require(AspectRatioPreset.square.ratio)
        #expect(abs(ratio - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test func ratio16x9_value() throws {
        let ratio = try #require(AspectRatioPreset.ratio16x9.ratio)
        #expect(abs(ratio - 16.0 / 9.0) < AppConstants.floatingPointTolerance)
    }

    @Test func ratio9x16_isReciprocal() throws {
        let r16x9 = try #require(AspectRatioPreset.ratio16x9.ratio)
        let r9x16 = try #require(AspectRatioPreset.ratio9x16.ratio)
        #expect(abs(r16x9 * r9x16 - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test func ratio4x3_value() throws {
        let ratio = try #require(AspectRatioPreset.ratio4x3.ratio)
        #expect(abs(ratio - 4.0 / 3.0) < AppConstants.floatingPointTolerance)
    }

    @Test func ratio3x2_value() throws {
        let ratio = try #require(AspectRatioPreset.ratio3x2.ratio)
        #expect(abs(ratio - 3.0 / 2.0) < AppConstants.floatingPointTolerance)
    }

    @Test func allCases_count() {
        #expect(AspectRatioPreset.allCases.count == 9)
    }

    @Test func allRatios_nonNegative() {
        for preset in AspectRatioPreset.allCases {
            if let ratio = preset.ratio {
                #expect(ratio > 0)
            }
        }
    }

    @Test func fromPresetName_validName() {
        let result = AspectRatioPreset.from(presetName: "square")
        #expect(result == .square)
    }

    @Test func fromPresetName_nil() {
        let result = AspectRatioPreset.from(presetName: nil)
        #expect(result == nil)
    }

    @Test func fromPresetName_invalidName() {
        let result = AspectRatioPreset.from(presetName: "invalid")
        #expect(result == nil)
    }

    @Test func rawValues_allUnique() {
        let rawValues = AspectRatioPreset.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test func localizedName_notEmpty() {
        for preset in AspectRatioPreset.allCases {
            #expect(!preset.localizedName.isEmpty)
        }
    }
}
