import Cocoa
import CoreImage
import os.log
import Vision

// MARK: - Background Removal Error

@available(macOS 14.0, *)
enum BackgroundRemovalError: LocalizedError, Equatable, CaseIterable, Sendable {
    case cgImageConversionFailed
    case noForegroundDetected
    case maskGenerationFailed
    case filterOutputFailed
    case finalImageConversionFailed

    private var localizationKey: String {
        switch self {
        case .cgImageConversionFailed:
            return "background_removal.error.conversion_failed"
        case .noForegroundDetected:
            return "background_removal.error.no_foreground"
        case .maskGenerationFailed:
            return "background_removal.error.mask_failed"
        case .filterOutputFailed:
            return "background_removal.error.filter_failed"
        case .finalImageConversionFailed:
            return "background_removal.error.final_conversion_failed"
        }
    }

    var errorDescription: String? {
        return NSLocalizedString(localizationKey, comment: "")
    }
}

// MARK: - Background Removal Manager

@available(macOS 14.0, *)
final class BackgroundRemovalManager: @unchecked Sendable {
    static let shared = BackgroundRemovalManager()

    private let logger = Logger(
        subsystem: AppConstants.loggerSubsystem,
        category: "BackgroundRemovalManager"
    )

    private let processingQueue = DispatchQueue(
        label: "\(AppConstants.loggerSubsystem).backgroundRemoval",
        qos: .userInitiated
    )

    private let ciContext = CIContext()

    init() {}

    func removeBackground(
        from image: NSImage,
        completion: @Sendable @escaping (Result<NSImage, BackgroundRemovalError>) -> Void
    ) {
        processingQueue.async { @Sendable [weak self] in
            guard let self else { return }
            do {
                let result = try self.performRemoval(from: image)
                DispatchQueue.main.async { @Sendable in completion(.success(result)) }
            } catch let error as BackgroundRemovalError {
                self.logger.error("Background removal failed: \(String(describing: error))")
                DispatchQueue.main.async { @Sendable in completion(.failure(error)) }
            } catch {
                self.logger.error("Unexpected error: \(String(describing: error))")
                DispatchQueue.main.async { @Sendable in completion(.failure(.maskGenerationFailed)) }
            }
        }
    }

    private func performRemoval(from image: NSImage) throws -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw BackgroundRemovalError.cgImageConversionFailed
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw BackgroundRemovalError.noForegroundDetected
        }

        let maskPixelBuffer: CVPixelBuffer
        do {
            maskPixelBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
        } catch {
            throw BackgroundRemovalError.maskGenerationFailed
        }

        let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        let inputCIImage = CIImage(cgImage: cgImage)

        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            throw BackgroundRemovalError.filterOutputFailed
        }
        filter.setValue(inputCIImage, forKey: kCIInputImageKey)
        filter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
        filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)

        guard let outputCIImage = filter.outputImage else {
            throw BackgroundRemovalError.filterOutputFailed
        }

        guard let outputCGImage = ciContext.createCGImage(outputCIImage, from: inputCIImage.extent) else {
            throw BackgroundRemovalError.finalImageConversionFailed
        }

        return NSImage(cgImage: outputCGImage, size: image.size)
    }
}
