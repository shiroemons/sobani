import Cocoa

/// iPhone風ルーラーダイヤル（-45°〜+45°）
/// 固定の黄色い中央インジケーターに対してルーラーがスクロールする
@MainActor
final class StraightenSliderView: NSView {

    // MARK: - Properties

    var angle: CGFloat = 0 {
        didSet {
            angle = CropGeometry.clampStraightenAngle(angle)
            needsDisplay = true
        }
    }

    var onAngleChanged: ((CGFloat) -> Void)?
    private var isDragging = false
    private var dragStartAngle: CGFloat = 0
    private var dragStartX: CGFloat = 0

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let centerX = bounds.midX
        // ルーラー目盛りエリアの垂直中心（下部に度数ラベル）
        let tickLabelHeight: CGFloat = 12   // 下部の度数ラベルスペース
        let tickAreaHeight = bounds.height - tickLabelHeight
        let tickAreaMidY = tickLabelHeight + tickAreaHeight / 2

        drawTicks(context: context, centerX: centerX, centerY: tickAreaMidY)
        drawCenterIndicator(context: context, centerX: centerX, centerY: tickAreaMidY)
    }

    private func drawTicks(context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        let tickSpacing = AppConstants.cropEditorRulerTickSpacing
        // 現在の角度に対応するルーラーオフセット（角度が増えるとルーラーは左へ）
        let rulerOffset = -angle * tickSpacing

        // クリッピング領域を設定してビュー外の目盛りを非表示に
        context.saveGState()
        context.clip(to: bounds)

        let minAngle = Int(AppConstants.straightenMinAngle)
        let maxAngle = Int(AppConstants.straightenMaxAngle)

        for tickDeg in minAngle...maxAngle {
            let tickAngle = CGFloat(tickDeg)
            let tickX = centerX + tickAngle * tickSpacing + rulerOffset

            // ビューの範囲外は描画しない（パフォーマンス最適化）
            guard tickX >= bounds.minX - tickSpacing && tickX <= bounds.maxX + tickSpacing else {
                continue
            }

            let isMajor = tickDeg % Int(AppConstants.straightenMajorTickInterval) == 0
            let isMinor = tickDeg % Int(AppConstants.straightenMinorTickInterval) == 0

            let tickHeight: CGFloat
            let lineWidth: CGFloat
            if isMajor {
                tickHeight = 14
                lineWidth = 1.5
            } else if isMinor {
                tickHeight = 10
                lineWidth = 1.0
            } else {
                tickHeight = 6
                lineWidth = 0.5
            }

            context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: tickX, y: centerY - tickHeight / 2))
            context.addLine(to: CGPoint(x: tickX, y: centerY + tickHeight / 2))
            context.strokePath()

            // 主目盛り（15°ごと）に角度ラベルを描画
            if isMajor {
                let labelText = "\(tickDeg)°"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let attrString = NSAttributedString(string: labelText, attributes: attrs)
                let size = attrString.size()
                let drawPoint = NSPoint(
                    x: tickX - size.width / 2,
                    y: centerY - tickHeight / 2 - size.height - 2
                )
                attrString.draw(at: drawPoint)
            }
        }

        context.restoreGState()
    }

    private func drawCenterIndicator(context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        // 下向き三角形インジケーター（黄色、上部中央固定）
        let triangleSize: CGFloat = 8
        let triangleTip = centerY + 14 / 2 + 4  // 最長目盛り上端より少し上

        context.saveGState()

        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: centerX, y: triangleTip - triangleSize))
        trianglePath.addLine(to: CGPoint(x: centerX - triangleSize / 2, y: triangleTip))
        trianglePath.addLine(to: CGPoint(x: centerX + triangleSize / 2, y: triangleTip))
        trianglePath.closeSubpath()

        context.setFillColor(NSColor.systemYellow.cgColor)
        context.addPath(trianglePath)
        context.fillPath()

        context.restoreGState()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isDragging = true
        dragStartAngle = angle
        dragStartX = point.x
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartX
        // ドラッグ方向と角度変化の関係: 左ドラッグ → 角度増加（ルーラーが左にスクロール）
        let deltaAngle = -deltaX / AppConstants.cropEditorRulerTickSpacing
        angle = CropGeometry.clampStraightenAngle(dragStartAngle + deltaAngle)
        onAngleChanged?(angle)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    // MARK: - Public

    func reset() {
        angle = 0
        onAngleChanged?(0)
    }
}
