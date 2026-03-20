import Cocoa

// MARK: - CharacterWindow + Background Removal

extension CharacterWindow {
    @objc func removeBackground() {
        removeBackground(completion: nil)
    }

    func removeBackground(completion: (@MainActor @Sendable () -> Void)?) {
        guard !isRemovingBackground else { return }
        guard #available(macOS 14.0, *) else { return }
        isRemovingBackground = true
        guard let currentImage = imageView.image else {
            isRemovingBackground = false
            return
        }
        showSpinner()
        BackgroundRemovalManager.shared.removeBackground(from: currentImage) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.hideSpinner()
                self.isRemovingBackground = false
                switch result {
                case .success(let newImage):
                    let baseName = URL(fileURLWithPath: self.displayName).deletingPathExtension().lastPathComponent
                    let newName = "\(baseName)_nobg.png"
                    ImageManager.shared.registerImage(newImage, name: newName)
                    self.displayName = newName
                    self.applyImage(newImage)
                case .failure(let error):
                    AlertFactory.make(
                        style: .warning,
                        messageText: L("background_removal.error.title"),
                        informativeText: error.localizedDescription,
                        buttonTitles: [L("update.ok")]
                    ).runModal()
                }
                completion?()
            }
        }
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
