import Foundation

// MARK: - CropShape

enum CropShape: String, Codable, Sendable, CaseIterable {
    case rectangle
    case circle
    case roundedRectangle
}

// MARK: - CornerRadii

struct CornerRadii: Codable, Equatable, Sendable {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat

    static let zero = Self(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)
    static let defaultRadius = AppConstants.cornerRadiusDefault
    static let defaultLinked = Self(
        topLeft: defaultRadius, topRight: defaultRadius,
        bottomLeft: defaultRadius, bottomRight: defaultRadius
    )

    func with(
        topLeft: CGFloat? = nil, topRight: CGFloat? = nil,
        bottomLeft: CGFloat? = nil, bottomRight: CGFloat? = nil
    ) -> Self {
        Self(
            topLeft: topLeft ?? self.topLeft,
            topRight: topRight ?? self.topRight,
            bottomLeft: bottomLeft ?? self.bottomLeft,
            bottomRight: bottomRight ?? self.bottomRight
        )
    }

    static func uniform(_ value: CGFloat) -> Self {
        Self(topLeft: value, topRight: value, bottomLeft: value, bottomRight: value)
    }

    func radius(for corner: CropGeometry.Corner) -> CGFloat {
        switch corner {
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }

    func with(corner: CropGeometry.Corner, radius: CGFloat) -> Self {
        switch corner {
        case .topLeft: return with(topLeft: radius)
        case .topRight: return with(topRight: radius)
        case .bottomLeft: return with(bottomLeft: radius)
        case .bottomRight: return with(bottomRight: radius)
        }
    }

    var isAllEqual: Bool {
        abs(topLeft - topRight) < AppConstants.floatingPointTolerance
            && abs(topLeft - bottomLeft) < AppConstants.floatingPointTolerance
            && abs(topLeft - bottomRight) < AppConstants.floatingPointTolerance
    }
}

// MARK: - CropRect

struct CropRect: Codable, Equatable, Sendable {
    let x: CGFloat       // 0.0〜1.0 ratio from left
    let y: CGFloat       // 0.0〜1.0 ratio from bottom
    let width: CGFloat   // 0.0〜1.0 ratio
    let height: CGFloat  // 0.0〜1.0 ratio

    let straightenAngle: CGFloat  // 傾き補正（-45〜+45°、デフォルト0）
    let quarterTurns: Int         // 90°回転回数（0〜3、デフォルト0）
    let isFlippedInCrop: Bool     // クロップ内反転（デフォルトfalse）
    let aspectRatioPreset: String? // アスペクト比プリセット名（nil=フリー）
    let verticalPerspective: CGFloat   // 垂直方向パース補正（-45〜+45、デフォルト0）
    let horizontalPerspective: CGFloat // 水平方向パース補正（-45〜+45、デフォルト0）
    let shape: CropShape          // default .rectangle
    let cornerRadii: CornerRadii  // default .zero
    let cornersLinked: Bool       // default true

    static let full = Self(x: 0, y: 0, width: 1, height: 1)

    init(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        straightenAngle: CGFloat = 0,
        quarterTurns: Int = 0,
        isFlippedInCrop: Bool = false,
        aspectRatioPreset: String? = nil,
        verticalPerspective: CGFloat = 0,
        horizontalPerspective: CGFloat = 0,
        shape: CropShape = .rectangle,
        cornerRadii: CornerRadii = .zero,
        cornersLinked: Bool = true
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.straightenAngle = straightenAngle
        self.quarterTurns = quarterTurns
        self.isFlippedInCrop = isFlippedInCrop
        self.aspectRatioPreset = aspectRatioPreset
        self.verticalPerspective = verticalPerspective
        self.horizontalPerspective = horizontalPerspective
        self.shape = shape
        self.cornerRadii = cornerRadii
        self.cornersLinked = cornersLinked
    }

    // MARK: - Copy Helper

    /// フィールドを選択的に上書きしたコピーを返す
    func with(
        x: CGFloat? = nil, y: CGFloat? = nil,
        width: CGFloat? = nil, height: CGFloat? = nil,
        straightenAngle: CGFloat? = nil,
        quarterTurns: Int? = nil,
        isFlippedInCrop: Bool? = nil,
        aspectRatioPreset: String?? = nil,
        verticalPerspective: CGFloat? = nil,
        horizontalPerspective: CGFloat? = nil,
        shape: CropShape? = nil,
        cornerRadii: CornerRadii? = nil,
        cornersLinked: Bool? = nil
    ) -> Self {
        Self(
            x: x ?? self.x,
            y: y ?? self.y,
            width: width ?? self.width,
            height: height ?? self.height,
            straightenAngle: straightenAngle ?? self.straightenAngle,
            quarterTurns: quarterTurns ?? self.quarterTurns,
            isFlippedInCrop: isFlippedInCrop ?? self.isFlippedInCrop,
            aspectRatioPreset: aspectRatioPreset ?? self.aspectRatioPreset,
            verticalPerspective: verticalPerspective ?? self.verticalPerspective,
            horizontalPerspective: horizontalPerspective ?? self.horizontalPerspective,
            shape: shape ?? self.shape,
            cornerRadii: cornerRadii ?? self.cornerRadii,
            cornersLinked: cornersLinked ?? self.cornersLinked
        )
    }

    // カスタムデコーダ（後方互換：旧JSON対応）
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
        case straightenAngle, quarterTurns, isFlippedInCrop, aspectRatioPreset
        case verticalPerspective, horizontalPerspective
        case shapeType, cornerRadii, cornersLinked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        width = try container.decode(CGFloat.self, forKey: .width)
        height = try container.decode(CGFloat.self, forKey: .height)
        straightenAngle = try container.decodeIfPresent(CGFloat.self, forKey: .straightenAngle) ?? 0
        quarterTurns = try container.decodeIfPresent(Int.self, forKey: .quarterTurns) ?? 0
        isFlippedInCrop = try container.decodeIfPresent(Bool.self, forKey: .isFlippedInCrop) ?? false
        aspectRatioPreset = try container.decodeIfPresent(String.self, forKey: .aspectRatioPreset)
        verticalPerspective = try container.decodeIfPresent(CGFloat.self, forKey: .verticalPerspective) ?? 0
        horizontalPerspective = try container.decodeIfPresent(CGFloat.self, forKey: .horizontalPerspective) ?? 0
        shape = (try? container.decodeIfPresent(CropShape.self, forKey: .shapeType)) ?? .rectangle
        cornerRadii = try container.decodeIfPresent(CornerRadii.self, forKey: .cornerRadii) ?? .zero
        cornersLinked = try container.decodeIfPresent(Bool.self, forKey: .cornersLinked) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(straightenAngle, forKey: .straightenAngle)
        try container.encode(quarterTurns, forKey: .quarterTurns)
        try container.encode(isFlippedInCrop, forKey: .isFlippedInCrop)
        try container.encode(aspectRatioPreset, forKey: .aspectRatioPreset)
        try container.encode(verticalPerspective, forKey: .verticalPerspective)
        try container.encode(horizontalPerspective, forKey: .horizontalPerspective)
        try container.encode(shape, forKey: .shapeType)
        try container.encode(cornerRadii, forKey: .cornerRadii)
        try container.encode(cornersLinked, forKey: .cornersLinked)
    }

    // MARK: - Approximate Equality

    /// 浮動小数点トレランス付きの等価比較
    func isEffectivelyEqual(to other: Self) -> Bool {
        let tol = AppConstants.floatingPointTolerance
        return abs(x - other.x) < tol
            && abs(y - other.y) < tol
            && abs(width - other.width) < tol
            && abs(height - other.height) < tol
            && abs(straightenAngle - other.straightenAngle) < tol
            && quarterTurns == other.quarterTurns
            && isFlippedInCrop == other.isFlippedInCrop
            && aspectRatioPreset == other.aspectRatioPreset
            && abs(verticalPerspective - other.verticalPerspective) < tol
            && abs(horizontalPerspective - other.horizontalPerspective) < tol
            && shape == other.shape
            && cornerRadii == other.cornerRadii
            && cornersLinked == other.cornersLinked
    }
}
