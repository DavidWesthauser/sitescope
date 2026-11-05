import CoreImage
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// A small, optional scene photo helps a person find an already-mapped viewpoint.
/// It is never used as an AR image anchor or as proof of alignment.
enum ScanGuideImage {
    /// The captured camera buffer is only read, never written, so handing it to a background task is safe.
    private struct FrameHandoff: @unchecked Sendable { let buffer: CVPixelBuffer }
    static func capture(_ pixelBuffer: CVPixelBuffer) async -> String? {
        let frame = FrameHandoff(buffer: pixelBuffer)
        return await Task.detached(priority: .utility) {
            let image = CIImage(cvPixelBuffer: frame.buffer).oriented(.right)
            let extent = image.extent
            guard extent.width > 0, extent.height > 0 else { return nil as String? }
            let scale = min(1, 512 / max(extent.width, extent.height))
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let context = CIContext(options: [.cacheIntermediates: false])
            guard let cg = context.createCGImage(scaled, from: scaled.extent.integral) else { return nil }
            for quality in [0.45, 0.3, 0.15] {
                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
                CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { return nil }
                if output.length <= 65_536 { return (output as Data).base64EncodedString() }
            }
            return nil
        }.value
    }

    static func thumbnail(_ encoded: String) -> UIImage? {
        guard let data = Data(base64Encoded: encoded), data.count <= 65_536,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
