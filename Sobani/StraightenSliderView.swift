import Cocoa

/// iPhone風ルーラーダイヤル（-45°〜+45°）
/// 固定の黄色い中央インジケーターに対してルーラーがスクロールする
@MainActor
final class StraightenSliderView: NSView {

    // MARK: - Properties

    var angle: CGFloat = 0 {
        didSet {
            let oldAngle = oldValue
            angle = CropGeometry.clampStraightenAngle(angle)
            angle = snapToZeroIfNeeded(angle)
            detectCrossedTicks(from: oldAngle, to: angle)
            needsDisplay = true
        }
    }

    var onAngleChanged: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var isDragging = false
    private var dragStartAngle: CGFloat = 0
    private var dragStartX: CGFloat = 0

    // Inertia
    private var inertiaVelocity: CGFloat = 0
    nonisolated(unsafe) private var inertiaTimer: Timer?
    private var lastDragTime: TimeInterval = 0
    private var lastDragAngle: CGFloat = 0

    // Fade trail
    private var fadingTicks: [Int: TimeInterval] = [:]
    nonisolated(unsafe) private var fadeTimer: Timer?
    private var previousAngle: CGFloat = 0

    // MARK: - Constants

    private static let majorTickHeight: CGFloat = 14
    private static let minorTickHeight: CGFloat = 10
    private static let normalTickHeight: CGFloat = 6
    private static let majorTickWidth: CGFloat = 1.0
    private static let minorTickWidth: CGFloat = 0.75
    private static let normalTickWidth: CGFloat = 0.5
    private static let tickLabelFontSize: CGFloat = 8
    private static let tickLabelSpacing: CGFloat = 2
    private static let tickLabelAreaHeight: CGFloat = 12

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let centerX = bounds.midX
        // ルーラー目盛りエリアの垂直中心（下部に度数ラベル）
        let tickLabelHeight = Self.tickLabelAreaHeight
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
            let tickX = centerX + CGFloat(tickDeg) * tickSpacing + rulerOffset

            // ビューの範囲外は描画しない（パフォーマンス最適化）
            guard tickX >= bounds.minX - tickSpacing && tickX <= bounds.maxX + tickSpacing else {
                continue
            }

            let isMajor = tickDeg % Int(AppConstants.straightenMajorTickInterval) == 0
            let isMinor = tickDeg % Int(AppConstants.straightenMinorTickInterval) == 0

            var tickHeight: CGFloat
            var lineWidth: CGFloat
            var tickColor: CGColor

            let fadeProgress: CGFloat?
            if let fadeStart = fadingTicks[tickDeg] {
                let elapsed = CACurrentMediaTime() - fadeStart
                fadeProgress = min(
                    CGFloat(elapsed) / Double(AppConstants.straightenFadeDuration), 1.0
                )
            } else {
                fadeProgress = nil
            }

            if let progress = fadeProgress {
                let normalHeight: CGFloat = isMajor ? Self.majorTickHeight
                    : isMinor ? Self.minorTickHeight : Self.normalTickHeight
                tickHeight = AppConstants.straightenFadeHighlightHeight
                    - (AppConstants.straightenFadeHighlightHeight - normalHeight) * progress
                let normalWidth: CGFloat = isMajor ? Self.majorTickWidth
                    : isMinor ? Self.minorTickWidth : Self.normalTickWidth
                lineWidth = AppConstants.straightenFadeHighlightWidth
                    - (AppConstants.straightenFadeHighlightWidth - normalWidth) * progress
                tickColor = NSColor.labelColor.blended(
                    withFraction: progress, of: NSColor.secondaryLabelColor
                )?.cgColor ?? NSColor.secondaryLabelColor.cgColor
            } else if isMajor {
                tickHeight = Self.majorTickHeight
                lineWidth = Self.majorTickWidth
                tickColor = NSColor.secondaryLabelColor.cgColor
            } else if isMinor {
                tickHeight = Self.minorTickHeight
                lineWidth = Self.minorTickWidth
                tickColor = NSColor.secondaryLabelColor.cgColor
            } else {
                tickHeight = Self.normalTickHeight
                lineWidth = Self.normalTickWidth
                tickColor = NSColor.secondaryLabelColor.cgColor
            }

            context.setStrokeColor(tickColor)
            context.setLineWidth(lineWidth)
            context.move(to: CGPoint(x: tickX, y: centerY - tickHeight / 2))
            context.addLine(to: CGPoint(x: tickX, y: centerY + tickHeight / 2))
            context.strokePath()

            // 主目盛り（15°ごと）と0°に角度ラベルを描画
            if isMajor || tickDeg == 0 {
                let labelText = "\(tickDeg)°"
                let labelColor: NSColor
                if let progress = fadeProgress {
                    labelColor = NSColor.labelColor.blended(
                        withFraction: progress, of: NSColor.secondaryLabelColor
                    ) ?? NSColor.secondaryLabelColor
                } else {
                    labelColor = NSColor.secondaryLabelColor
                }
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: Self.tickLabelFontSize, weight: .regular),
                    .foregroundColor: labelColor
                ]
                let attrString = NSAttributedString(string: labelText, attributes: attrs)
                let size = attrString.size()
                let drawPoint = NSPoint(
                    x: tickX - size.width / 2,
                    y: centerY - tickHeight / 2 - size.height - Self.tickLabelSpacing
                )
                attrString.draw(at: drawPoint)
            }
        }

        context.restoreGState()
    }

    private func drawCenterIndicator(context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        // iPhone風: 他のティックより長い黄色バーで現在位置を示す
        let barHeight = AppConstants.straightenFadeHighlightHeight
        let barWidth = AppConstants.straightenFadeHighlightWidth

        context.saveGState()
        context.setStrokeColor(NSColor.systemYellow.cgColor)
        context.setLineWidth(barWidth)
        context.move(to: CGPoint(x: centerX, y: centerY - barHeight / 2))
        context.addLine(to: CGPoint(x: centerX, y: centerY + barHeight / 2))
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        stopInertia()
        let point = convert(event.locationInWindow, from: nil)
        isDragging = true
        dragStartAngle = angle
        dragStartX = point.x
        lastDragTime = event.timestamp
        lastDragAngle = angle
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartX
        // ドラッグ方向と角度変化の関係: 左ドラッグ → 角度増加（ルーラーが左にスクロール）
        let deltaAngle = -deltaX / AppConstants.cropEditorRulerTickSpacing
        let newAngle = CropGeometry.clampStraightenAngle(dragStartAngle + deltaAngle)

        // 慣性用の速度計算
        let currentTime = event.timestamp
        let timeDelta = currentTime - lastDragTime
        if timeDelta > 0 {
            inertiaVelocity = (newAngle - lastDragAngle) / CGFloat(timeDelta)
                * CGFloat(AppConstants.straightenInertiaFrameInterval)
        }
        lastDragTime = currentTime
        lastDragAngle = newAngle

        angle = newAngle
        onAngleChanged?(angle)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if !startInertiaIfNeeded() {
            let snapped = snapToZeroIfNeeded(angle)
            if snapped != angle {
                angle = snapped
                onAngleChanged?(angle)
            }
            onDragEnded?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        stopInertia()
        let delta = event.scrollingDeltaY * AppConstants.straightenScrollSensitivity
        angle = CropGeometry.clampStraightenAngle(angle - delta)
        onAngleChanged?(angle)
    }

    // MARK: - Lifecycle

    deinit {
        inertiaTimer?.invalidate()
        fadeTimer?.invalidate()
    }

    // MARK: - Public

    func stopTimers() {
        stopInertia()
        stopFadeTrail()
    }

    func reset() {
        stopInertia()
        stopFadeTrail()
        angle = 0
        onAngleChanged?(0)
    }

    // MARK: - Inertia

    @discardableResult
    private func startInertiaIfNeeded() -> Bool {
        guard abs(inertiaVelocity) >= AppConstants.straightenInertiaMinVelocity
        else { return false }
        inertiaTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.straightenInertiaFrameInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateInertia()
            }
        }
        return true
    }

    private func updateInertia() {
        inertiaVelocity *= AppConstants.straightenInertiaDecayRate
        let newAngle = CropGeometry.clampStraightenAngle(angle + inertiaVelocity)

        // 0°スナップ判定: 0°付近かつ速度が低い場合
        if abs(newAngle) <= AppConstants.straightenZeroSnapThreshold
            && abs(inertiaVelocity) < AppConstants.straightenInertiaMinVelocity * 3 {
            angle = 0
            onAngleChanged?(angle)
            stopInertia()
            return
        }

        // 端到達で停止
        if newAngle == AppConstants.straightenMinAngle
            || newAngle == AppConstants.straightenMaxAngle {
            angle = newAngle
            onAngleChanged?(angle)
            stopInertia()
            return
        }

        // 速度閾値以下で停止
        if abs(inertiaVelocity) < AppConstants.straightenInertiaMinVelocity {
            onAngleChanged?(angle)
            stopInertia()
            return
        }

        angle = newAngle
        onAngleChanged?(angle)
    }

    private func stopInertia() {
        let wasRunning = inertiaTimer != nil
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        inertiaVelocity = 0
        if wasRunning {
            onDragEnded?()
        }
    }

    // MARK: - Fade Trail

    private func detectCrossedTicks(from oldAngle: CGFloat, to newAngle: CGFloat) {
        guard !GeometryUtils.isApproximatelyEqual(oldAngle, newAngle) else { return }
        let minDeg = Int(floor(min(oldAngle, newAngle)))
        let maxDeg = Int(ceil(max(oldAngle, newAngle)))
        guard minDeg <= maxDeg else { return }
        let now = CACurrentMediaTime()
        for deg in minDeg...maxDeg {
            let degF = CGFloat(deg)
            if (oldAngle < degF && degF <= newAngle)
                || (newAngle < degF && degF <= oldAngle)
                || GeometryUtils.isApproximatelyEqual(degF, oldAngle) {
                fadingTicks[deg] = now
            }
        }
        startFadeTimerIfNeeded()
    }

    private func startFadeTimerIfNeeded() {
        guard fadeTimer == nil, !fadingTicks.isEmpty else { return }
        fadeTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.straightenInertiaFrameInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateFade()
            }
        }
    }

    private func updateFade() {
        let now = CACurrentMediaTime()
        fadingTicks = fadingTicks.filter {
            now - $0.value < Double(AppConstants.straightenFadeDuration)
        }
        if fadingTicks.isEmpty {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
        needsDisplay = true
    }

    private func stopFadeTrail() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadingTicks.removeAll()
    }

    // MARK: - Snap

    private func snapToZeroIfNeeded(_ value: CGFloat) -> CGFloat {
        if !isDragging && inertiaTimer == nil
            && abs(value) <= AppConstants.straightenZeroSnapThreshold {
            return 0
        }
        return value
    }
}
