import Cocoa

// MARK: - Toolbar Handlers

extension CropEditorPanelController {

    func handleStraightenAngleChanged(_ angle: CGFloat) {
        let clamped = CropGeometry.clampStraightenAngle(angle)
        let currentMode = toolbarView?.currentStraightenMode ?? .straighten
        var updated: CropRect
        switch currentMode {
        case .straighten:
            updated = currentCropRect.with(straightenAngle: clamped)
        case .verticalPerspective:
            updated = currentCropRect.with(verticalPerspective: clamped)
        case .horizontalPerspective:
            updated = currentCropRect.with(horizontalPerspective: clamped)
        }
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
        updateRevertButtonVisibility()
    }

    func handleRotate90() {
        var updated = CropGeometry.cropRectAfterQuarterTurn(cropRect: currentCropRect, turns: 1)
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
    }

    func handleAspectRatioSelected(_ preset: AspectRatioPreset) {
        let imageSize = effectiveImageSize()
        if let ratio = resolveAspectRatio(for: preset, imageSize: imageSize) {
            let base = CropGeometry.cropRectForAspectRatio(
                ratio: ratio, within: imageSize
            )
            currentCropRect = currentCropRect.with(
                x: base.x, y: base.y,
                width: base.width, height: base.height,
                aspectRatioPreset: .some(preset.rawValue)
            )
        } else {
            // フリー: aspectRatioPresetのみ更新、サイズ変更なし
            currentCropRect = currentCropRect.with(aspectRatioPreset: .some(preset.rawValue))
        }
        canvasView?.initializeFromCropRect(currentCropRect)
        toolbarView?.updateAspectRatioSelection(preset)
        toolbarView?.updateShapeAspectOrientation(currentAspectOrientation(currentCropRect))
        recordCurrentState()
        updateRevertButtonVisibility()
    }
}

// MARK: - Aspect Ratio Helpers

extension CropEditorPanelController {

    /// 現在の画像サイズを取得（フォールバック: 1:1）
    func effectiveImageSize() -> CGSize {
        guard let size = originalImage?.size, size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return size
    }

    /// プリセットに対応するアスペクト比を解決する（free は nil を返す）
    func resolveAspectRatio(for preset: AspectRatioPreset, imageSize: CGSize) -> CGFloat? {
        switch preset {
        case .original:
            return imageSize.width / imageSize.height
        default:
            return preset.ratio
        }
    }

    /// 現在設定されているアスペクト比制約を再適用する
    func applyCurrentAspectRatioConstraint(to rect: CropRect) -> CropRect {
        guard let preset = AspectRatioPreset.from(presetName: rect.aspectRatioPreset) else {
            return rect
        }
        let imageSize = effectiveImageSize()
        guard let ratio = resolveAspectRatio(for: preset, imageSize: imageSize) else {
            return rect
        }
        let constrained = CropGeometry.constrainCropRect(
            rect, toAspectRatio: ratio, within: imageSize
        )
        return rect.with(
            x: constrained.x, y: constrained.y,
            width: constrained.width, height: constrained.height
        )
    }
}
