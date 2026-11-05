import UIKit
import ImageIO
import RealityKit

@MainActor struct PreparedSpatialImage {
    let data: Data
    let image: UIImage
    let texture: TextureResource
}
@MainActor enum SpatialImageAsset {
    /// Existing assets need a GPU texture, not another PNG export on the AR callback queue.
    static func loadTexture(_ data: Data) async throws -> TextureResource {
        try Task.checkCancellation()
        guard data.count <= 30_000_000 else {
            throw AppError.message("This image could not be loaded (maximum 30 MB).")
        }
        let decoding = Task.detached(priority: .userInitiated) { () throws -> CGImage in
            try Task.checkCancellation()
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    // Display textures need less memory than the saved 2048px source image.
                    kCGImageSourceThumbnailMaxPixelSize: 1024,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else {
                throw AppError.message("This image could not be loaded (maximum 30 MB).")
            }
            try Task.checkCancellation()
            return image
        }
        let image = try await withTaskCancellationHandler {
            try await decoding.value
        } onCancel: {
            decoding.cancel()
        }
        try Task.checkCancellation()
        let texture: TextureResource
        if #available(iOS 18, *) {
            texture = try await TextureResource(image: image, options: .init(semantic: .color))
        } else {
            texture = try TextureResource.generate(from: image, withName: nil, options: .init(semantic: .color))
        }
        try Task.checkCancellation()
        return texture
    }

    /// Decoding and the 2048 px PNG encode take hundreds of milliseconds, so they run off the main actor;
    /// only the texture upload stays here.
    static func prepare(_ data: Data) async throws -> PreparedSpatialImage {
        guard data.count <= 30_000_000 else { throw AppError.message("This image could not be loaded (maximum 30 MB).") }
        let decoded = Task.detached(priority: .userInitiated) { () throws -> (cg: CGImage, png: Data) in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2048,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { throw AppError.message("This image could not be loaded (maximum 30 MB).") }
            try Task.checkCancellation()
            guard let png = UIImage(cgImage: cg).pngData() else { throw AppError.message("This image could not be processed.") }
            return (cg, png)
        }
        let (cg, png) = try await withTaskCancellationHandler { try await decoded.value } onCancel: { decoded.cancel() }
        try Task.checkCancellation()
        let texture: TextureResource
        if #available(iOS 18, *) { texture = try await TextureResource(image: cg, options: .init(semantic: .color)) }
        else { texture = try TextureResource.generate(from: cg, withName: nil, options: .init(semantic: .color)) }
        return PreparedSpatialImage(data: png, image: UIImage(cgImage: cg), texture: texture)
    }
}
