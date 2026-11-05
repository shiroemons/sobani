import Cocoa
import os.log

// MARK: - ImageWindow + Background Removal

extension ImageWindow {
    private static let backgroundRemovalLogger = Logger(category: "BackgroundRemoval")

    @objc func removeBackground() {
        removeBackground(completion: nil)
    }

    func removeBackground(completion: (@MainActor @Sendable () -> Void)?) {
        guard !isRemovingBackground else { return }
        guard #available(macOS 14.0, *) else { return }
        // クロップ済みの表示画像ではなく元画像を処理する（クロップは結果に再適用する）
        guard let sourceImage = imageView.originalImage ?? imageView.image else { return }
        isRemovingBackground = true
        showSpinner()
        BackgroundRemovalManager.shared.removeBackground(from: sourceImage) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.hideSpinner()
                self.isRemovingBackground = false
                defer { completion?() }
                // 処理中に画像が差し替えられた場合、古い結果で上書きしない
                guard (self.imageView.originalImage ?? self.imageView.image) === sourceImage else {
                    Self.backgroundRemovalLogger.notice("Discarded stale background removal result")
                    return
                }
                switch result {
                case .success(let newImage):
                    self.applyBackgroundRemovedImage(newImage)
                case .failure(let error):
                    self.showBackgroundRemovalError(error.localizedDescription)
                }
            }
        }
    }

    /// 背景除去済みの画像を登録し、クロップを保ったまま元画像として差し替える。
    private func applyBackgroundRemovedImage(_ newImage: NSImage) {
        let baseName = URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent
        // 同名ファイルがあると自動リネームされるため、戻り値の名前を使う
        guard let savedName = ImageManager.shared.registerImage(newImage, name: "\(baseName)_nobg.png") else {
            Self.backgroundRemovalLogger.error("Failed to register background-removed image")
            showBackgroundRemovalError(L("background_removal.error.save_failed"))
            return
        }
        displayName = savedName
        imageView.setOriginalImage(newImage)
        cachedHasAlpha = nil
        notifyStateDidChange(.image)
    }

    private func showBackgroundRemovalError(_ message: String) {
        AlertFactory.make(
            style: .warning,
            messageText: L("background_removal.error.title"),
            informativeText: message,
            buttonTitles: [L("update.ok")]
        ).runModal()
    }

    private func showSpinner() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.sizeToFit()
        if let contentView = window.contentView {
            spinner.frame.origin = NSPoint(
                x: (contentView.bounds.width - spinner.frame.width) / 2,
                y: (contentView.bounds.height - spinner.frame.height) / 2
            )
            spinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
            contentView.addSubview(spinner)
            spinner.startAnimation(nil)
        }
        spinnerOverlay = spinner
    }

    private func hideSpinner() {
        spinnerOverlay?.stopAnimation(nil)
        spinnerOverlay?.removeFromSuperview()
        spinnerOverlay = nil
    }

    func imageHasAlpha() -> Bool {
        if let cached = cachedHasAlpha { return cached }
        let result = computeImageHasAlpha()
        cachedHasAlpha = result
        return result
    }

    private func computeImageHasAlpha() -> Bool {
        guard let image = imageView.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              Self.isAlphaInfoTransparent(cgImage.alphaInfo) else { return false }
        let (w, h) = (cgImage.width, cgImage.height)
        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return false }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        return stride(from: 3, to: w * h * 4, by: 4).contains { ptr[$0] < 255 }
    }
}
