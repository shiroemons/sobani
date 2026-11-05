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
        // アスペクト比制約で位置・サイズが変わることがあるため、ズーム/オフセットも作り直す
        canvasView?.initializeFromCropRect(currentCropRect)
        updateRevertButtonVisibility()
    }

    /// 表示上で時計回り（右）に 90° 回転する
    func handleRotate90() {
        var updated = CropGeometry.cropRectAfterQuarterTurn(cropRect: currentCropRect, turns: 1)
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        // 位置・サイズが変わるため cropRect だけでなくズーム/オフセットも作り直す
        // （古いオフセットのまま確定すると半分透明な画像が出力される）
        canvasView?.initializeFromCropRect(currentCropRect)
        // 回転でパース補正の縦横が入れ替わるため、ツールバーの表示も同期する
        syncToolbarState(to: currentCropRect)
    }

    func handleAspectRatioSelected(_ preset: AspectRatioPreset) {
        let imageSize = effectiveImageSize(for: currentCropRect)
        if let ratio = preset.ratio(forImageSize: imageSize) {
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

    /// CropRect の 90° 回転を反映した表示上の画像サイズ（画像がない場合は 1:1）
    func effectiveImageSize(for cropRect: CropRect) -> CGSize {
        guard let size = originalImage?.size, size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return CropGeometry.effectiveSize(size, quarterTurns: cropRect.quarterTurns)
    }

    /// 現在設定されているアスペクト比制約を再適用する
    func applyCurrentAspectRatioConstraint(to rect: CropRect) -> CropRect {
        let imageSize = effectiveImageSize(for: rect)
        guard let preset = AspectRatioPreset.from(presetName: rect.aspectRatioPreset),
              let ratio = preset.ratio(forImageSize: imageSize) else {
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
