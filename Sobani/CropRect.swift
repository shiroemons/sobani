import Foundation

// MARK: - CropRect

struct CropRect: Codable, Equatable, Sendable {
    let x: CGFloat       // 0.0〜1.0 ratio from left
    let y: CGFloat       // 0.0〜1.0 ratio from bottom
    let width: CGFloat   // 0.0〜1.0 ratio
    let height: CGFloat  // 0.0〜1.0 ratio

    // Phase 1: 新フィールド（iPhone風クロップUI用）
    let straightenAngle: CGFloat  // 傾き補正（-45〜+45°、デフォルト0）
    let quarterTurns: Int         // 90°回転回数（0〜3、デフォルト0）
    let isFlippedInCrop: Bool     // クロップ内反転（デフォルトfalse）
    let aspectRatioPreset: String? // アスペクト比プリセット名（nil=フリー）
    let verticalPerspective: CGFloat   // 垂直方向パース補正（-45〜+45、デフォルト0）
    let horizontalPerspective: CGFloat // 水平方向パース補正（-45〜+45、デフォルト0）

    static let full = Self(x: 0, y: 0, width: 1, height: 1)

    // 既存コードとの後方互換性のためのイニシャライザ
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
        horizontalPerspective: CGFloat = 0
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
        horizontalPerspective: CGFloat? = nil
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
            horizontalPerspective: horizontalPerspective ?? self.horizontalPerspective
        )
    }

    // カスタムデコーダ（後方互換：旧JSON対応）
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
        case straightenAngle, quarterTurns, isFlippedInCrop, aspectRatioPreset
        case verticalPerspective, horizontalPerspective
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
    }
}
