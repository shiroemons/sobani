import Foundation

// MARK: - CropShape

enum CropShape: String, Codable, Sendable, CaseIterable {
    case rectangle
    case circle
    case roundedRectangle
}

// MARK: - CornerRadii

struct CornerRadii: Codable, Hashable, Sendable {
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

    /// 4隅すべての半径がほぼ 0 か
    var isEffectivelyZero: Bool {
        isEffectivelyEqual(to: .zero)
    }

    /// 正規化座標の許容誤差で比較する
    func isEffectivelyEqual(to other: Self) -> Bool {
        let tol = AppConstants.normalizedTolerance
        return abs(topLeft - other.topLeft) < tol
            && abs(topRight - other.topRight) < tol
            && abs(bottomLeft - other.bottomLeft) < tol
            && abs(bottomRight - other.bottomRight) < tol
    }

    /// 非有限値を 0 に、範囲外の値を 0〜1 に収めたコピーを返す（保存データの読み込み用）
    func sanitized() -> Self {
        func clamp(_ value: CGFloat) -> CGFloat {
            guard value.isFinite else { return AppConstants.cornerRadiusMin }
            return min(max(value, AppConstants.cornerRadiusMin), AppConstants.cornerRadiusMax)
        }
        return Self(
            topLeft: clamp(topLeft), topRight: clamp(topRight),
            bottomLeft: clamp(bottomLeft), bottomRight: clamp(bottomRight)
        )
    }
}

// MARK: - CropRect

/// `==` / `hash` は値の完全一致（キャッシュキー用）。編集状態の比較には `isEffectivelyEqual(to:)` を使う
struct CropRect: Codable, Hashable, Sendable {
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

    /// 保存データから読み込む x / y / width / height の上限（画像サイズの倍数）。
    /// 画像外への自由配置は許容しつつ、壊れた値で巨大な画像を確保しようとするのを防ぐ
    static let maxExtent: CGFloat = 10
    /// 保存データから読み込む width / height の下限（0 以下の退化した矩形を防ぐ）
    private static let minExtent: CGFloat = 1e-4

    /// 90° 回転・反転・傾き補正・パース補正のいずれかを含むか（切り出し位置だけなら false）
    var hasImageTransform: Bool {
        CropGeometry.normalizeQuarterTurns(quarterTurns) != 0
            || isFlippedInCrop
            || !GeometryUtils.isApproximatelyZero(straightenAngle)
            || !GeometryUtils.isApproximatelyZero(verticalPerspective)
            || !GeometryUtils.isApproximatelyZero(horizontalPerspective)
    }

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

    /// 保存データは手編集や旧バージョンで壊れている可能性があるため、読み込み時に `sanitized()` で補正する
    /// （非有限値や巨大な値のまま画像処理に渡すと、起動時の復元でクラッシュする）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Self(
            x: try container.decode(CGFloat.self, forKey: .x),
            y: try container.decode(CGFloat.self, forKey: .y),
            width: try container.decode(CGFloat.self, forKey: .width),
            height: try container.decode(CGFloat.self, forKey: .height),
            straightenAngle: try container.decodeIfPresent(CGFloat.self, forKey: .straightenAngle) ?? 0,
            quarterTurns: try container.decodeIfPresent(Int.self, forKey: .quarterTurns) ?? 0,
            isFlippedInCrop: try container.decodeIfPresent(Bool.self, forKey: .isFlippedInCrop) ?? false,
            aspectRatioPreset: try container.decodeIfPresent(String.self, forKey: .aspectRatioPreset),
            verticalPerspective: try container.decodeIfPresent(CGFloat.self, forKey: .verticalPerspective) ?? 0,
            horizontalPerspective: try container.decodeIfPresent(CGFloat.self, forKey: .horizontalPerspective) ?? 0,
            shape: (try? container.decodeIfPresent(CropShape.self, forKey: .shapeType)) ?? .rectangle,
            cornerRadii: try container.decodeIfPresent(CornerRadii.self, forKey: .cornerRadii) ?? .zero,
            cornersLinked: try container.decodeIfPresent(Bool.self, forKey: .cornersLinked) ?? true
        ).sanitized()
    }

    // MARK: - Sanitization

    /// 非有限値・範囲外の値を安全な範囲へ補正したコピーを返す（保存データの読み込み・書き込みの両方で使う）。
    ///
    /// 位置は ±`maxExtent`、サイズは `minExtent`〜`maxExtent`、角度は ±45°、`quarterTurns` は 0〜3、
    /// 角丸は 0〜1 に収める。非有限値は既定値（位置・角度は 0、サイズは 1）にする。
    func sanitized() -> Self {
        Self(
            x: Self.sanitizedOrigin(x),
            y: Self.sanitizedOrigin(y),
            width: Self.sanitizedExtent(width),
            height: Self.sanitizedExtent(height),
            straightenAngle: Self.sanitizedAngle(straightenAngle),
            quarterTurns: CropGeometry.normalizeQuarterTurns(quarterTurns),
            isFlippedInCrop: isFlippedInCrop,
            aspectRatioPreset: aspectRatioPreset,
            verticalPerspective: Self.sanitizedAngle(verticalPerspective),
            horizontalPerspective: Self.sanitizedAngle(horizontalPerspective),
            shape: shape,
            cornerRadii: cornerRadii.sanitized(),
            cornersLinked: cornersLinked
        )
    }

    private static func sanitizedOrigin(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, -maxExtent), maxExtent)
    }

    private static func sanitizedExtent(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 1 }
        return min(max(value, minExtent), maxExtent)
    }

    private static func sanitizedAngle(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return CropGeometry.clampStraightenAngle(value)
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
    /// 正規化座標（位置・サイズ・角丸）は `normalizedTolerance`、角度（度）は `floatingPointTolerance` で比較する
    func isEffectivelyEqual(to other: Self) -> Bool {
        let normalizedTol = AppConstants.normalizedTolerance
        let angleTol = AppConstants.floatingPointTolerance
        return abs(x - other.x) < normalizedTol
            && abs(y - other.y) < normalizedTol
            && abs(width - other.width) < normalizedTol
            && abs(height - other.height) < normalizedTol
            && abs(straightenAngle - other.straightenAngle) < angleTol
            && CropGeometry.normalizeQuarterTurns(quarterTurns)
                == CropGeometry.normalizeQuarterTurns(other.quarterTurns)
            && isFlippedInCrop == other.isFlippedInCrop
            && aspectRatioPreset == other.aspectRatioPreset
            && abs(verticalPerspective - other.verticalPerspective) < angleTol
            && abs(horizontalPerspective - other.horizontalPerspective) < angleTol
            && shape == other.shape
            && cornerRadii.isEffectivelyEqual(to: other.cornerRadii)
            && cornersLinked == other.cornersLinked
    }
}
