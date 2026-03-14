import Foundation
import Testing
@testable import Sobani

@Suite struct CropShapeTests {

    // MARK: - CropShape

    @Test func cropShape_rawValues() {
        #expect(CropShape.rectangle.rawValue == "rectangle")
        #expect(CropShape.circle.rawValue == "circle")
        #expect(CropShape.roundedRectangle.rawValue == "roundedRectangle")
    }

    @Test func cropShape_codableRoundTrip() throws {
        for shape in CropShape.allCases {
            let data = try JSONEncoder().encode(shape)
            let decoded = try JSONDecoder().decode(CropShape.self, from: data)
            #expect(decoded == shape)
        }
    }

    // MARK: - CornerRadii

    @Test func cornerRadii_zero() {
        let zero = CornerRadii.zero
        #expect(abs(zero.topLeft) < AppConstants.floatingPointTolerance)
        #expect(abs(zero.topRight) < AppConstants.floatingPointTolerance)
        #expect(abs(zero.bottomLeft) < AppConstants.floatingPointTolerance)
        #expect(abs(zero.bottomRight) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadii_defaultLinked() {
        let linked = CornerRadii.defaultLinked
        let expected = CornerRadii.defaultRadius
        #expect(abs(linked.topLeft - expected) < AppConstants.floatingPointTolerance)
        #expect(abs(linked.topRight - expected) < AppConstants.floatingPointTolerance)
        #expect(abs(linked.bottomLeft - expected) < AppConstants.floatingPointTolerance)
        #expect(abs(linked.bottomRight - expected) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadii_with() {
        let radii = CornerRadii.zero.with(topLeft: 0.5, bottomRight: 0.8)
        #expect(abs(radii.topLeft - 0.5) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.topRight) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.bottomLeft) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.bottomRight - 0.8) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadii_uniform() {
        let radii = CornerRadii.uniform(0.4)
        #expect(abs(radii.topLeft - 0.4) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.topRight - 0.4) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.bottomLeft - 0.4) < AppConstants.floatingPointTolerance)
        #expect(abs(radii.bottomRight - 0.4) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadii_isAllEqual_true() {
        #expect(CornerRadii.zero.isAllEqual)
        #expect(CornerRadii.defaultLinked.isAllEqual)
        #expect(CornerRadii.uniform(0.5).isAllEqual)
    }

    @Test func cornerRadii_isAllEqual_false() {
        let radii = CornerRadii(topLeft: 0.1, topRight: 0.2, bottomLeft: 0.1, bottomRight: 0.1)
        #expect(!radii.isAllEqual)
    }

    @Test func cornerRadii_codableRoundTrip() throws {
        let radii = CornerRadii(topLeft: 0.1, topRight: 0.2, bottomLeft: 0.3, bottomRight: 0.4)
        let data = try JSONEncoder().encode(radii)
        let decoded = try JSONDecoder().decode(CornerRadii.self, from: data)
        #expect(decoded == radii)
    }

    // MARK: - CropRect Backward Compatibility

    @Test func cropRect_decodesOldJSON_withDefaults() throws {
        // Simulate old JSON without shape fields
        let json = """
        {"x": 0.1, "y": 0.2, "width": 0.5, "height": 0.6}
        """
        let data = try #require(json.data(using: .utf8))
        let rect = try JSONDecoder().decode(CropRect.self, from: data)
        #expect(rect.shape == .rectangle)
        #expect(rect.cornerRadii == .zero)
        #expect(rect.cornersLinked == true)
    }

    @Test func cropRect_newFields_codableRoundTrip() throws {
        let rect = CropRect(
            x: 0.1, y: 0.2, width: 0.5, height: 0.6,
            shape: .roundedRectangle,
            cornerRadii: CornerRadii(topLeft: 0.1, topRight: 0.2, bottomLeft: 0.3, bottomRight: 0.4),
            cornersLinked: false
        )
        let data = try JSONEncoder().encode(rect)
        let decoded = try JSONDecoder().decode(CropRect.self, from: data)
        #expect(decoded.shape == .roundedRectangle)
        #expect(decoded.cornerRadii == rect.cornerRadii)
        #expect(decoded.cornersLinked == false)
    }

    @Test func cropRect_isEffectivelyEqual_shapeDifference() {
        let rect1 = CropRect(x: 0, y: 0, width: 1, height: 1)
        let rect2 = CropRect(x: 0, y: 0, width: 1, height: 1, shape: .circle)
        #expect(!rect1.isEffectivelyEqual(to: rect2))
    }

    @Test func cropRect_isEffectivelyEqual_cornerRadiiDifference() {
        let rect1 = CropRect(x: 0, y: 0, width: 1, height: 1, cornerRadii: .zero)
        let rect2 = CropRect(x: 0, y: 0, width: 1, height: 1, cornerRadii: .defaultLinked)
        #expect(!rect1.isEffectivelyEqual(to: rect2))
    }

    @Test func cropRect_isEffectivelyEqual_cornersLinkedDifference() {
        let rect1 = CropRect(x: 0, y: 0, width: 1, height: 1, cornersLinked: true)
        let rect2 = CropRect(x: 0, y: 0, width: 1, height: 1, cornersLinked: false)
        #expect(!rect1.isEffectivelyEqual(to: rect2))
    }

    @Test func cropRect_shape_storedProperty() {
        #expect(CropRect.full.shape == .rectangle)
        let circle = CropRect(x: 0, y: 0, width: 1, height: 1, shape: .circle)
        #expect(circle.shape == .circle)
        let rounded = CropRect(x: 0, y: 0, width: 1, height: 1, shape: .roundedRectangle)
        #expect(rounded.shape == .roundedRectangle)
    }

    @Test func cropRect_with_shapeFields() {
        let rect = CropRect.full
        let updated = rect.with(
            shape: .circle,
            cornerRadii: .defaultLinked,
            cornersLinked: false
        )
        #expect(updated.shape == .circle)
        #expect(updated.cornerRadii == .defaultLinked)
        #expect(updated.cornersLinked == false)
        // Original fields unchanged
        #expect(abs(updated.x) < AppConstants.floatingPointTolerance)
        #expect(abs(updated.width - 1.0) < AppConstants.floatingPointTolerance)
    }
}
