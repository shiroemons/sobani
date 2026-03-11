import Foundation

/// クロップエディタで使用するアスペクト比プリセット
enum AspectRatioPreset: String, CaseIterable, Sendable {
    case original
    case free
    case square
    case ratio16x9
    case ratio9x16
    case ratio4x3
    case ratio3x4
    case ratio3x2
    case ratio2x3

    /// アスペクト比の数値（width / height）。free/originalはnil
    var ratio: CGFloat? {
        switch self {
        case .free, .original: return nil
        case .square: return 1.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio3x4: return 3.0 / 4.0
        case .ratio3x2: return 3.0 / 2.0
        case .ratio2x3: return 2.0 / 3.0
        }
    }

    /// ローカライズされた表示名
    var localizedName: String {
        L("aspect_ratio.\(rawValue)")
    }

    /// プリセット名からAspectRatioPresetを検索（CropRect.aspectRatioPreset用）
    static func from(presetName: String?) -> Self? {
        guard let name = presetName else { return nil }
        return Self(rawValue: name)
    }
}
