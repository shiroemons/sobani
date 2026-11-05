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
                case .success(let removal):
                    self.applyBackgroundRemovedImage(removal)
                case .failure(let error):
                    self.showBackgroundRemovalError(error.localizedDescription)
                }
            }
        }
    }

    /// 背景除去済みの画像を登録し、クロップを保ったまま元画像として差し替える。
    ///
    /// PNG へのエンコードは処理キューで済んでいるため、ここではファイルの書き込みと画像の差し替えだけを行う。
    private func applyBackgroundRemovedImage(_ removal: BackgroundRemovalResult) {
        // URL(fileURLWithPath:) は相対名をカレントディレクトリ基準で解決するため、文字列だけで分割する
        let baseName = PathSanitizer.splitExtension(PathSanitizer.lastPathComponent(of: displayName)).base
        // 同名ファイルがあると自動リネームされるため、戻り値の名前を使う
        guard let savedName = ImageManager.shared.registerPNGData(removal.pngData, name: "\(baseName)_nobg.png") else {
            Self.backgroundRemovalLogger.error("Failed to register background-removed image")
            showBackgroundRemovalError(L("background_removal.error.save_failed"))
            return
        }
        displayName = savedName
        imageView.setOriginalImage(removal.image)
        notifyStateDidChange(.image)
    }

    private func showBackgroundRemovalError(_ message: String) {
        AlertFactory.make(
            style: .warning,
            messageText: L("background_removal.error.title"),
            informativeText: message
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
}
