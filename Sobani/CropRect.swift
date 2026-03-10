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
        aspectRatioPreset: String? = nil
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.straightenAngle = straightenAngle
        self.quarterTurns = quarterTurns
        self.isFlippedInCrop = isFlippedInCrop
        self.aspectRatioPreset = aspectRatioPreset
    }

    // カスタムデコーダ（後方互換：旧JSON対応）
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
        case straightenAngle, quarterTurns, isFlippedInCrop, aspectRatioPreset
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
    }
}
