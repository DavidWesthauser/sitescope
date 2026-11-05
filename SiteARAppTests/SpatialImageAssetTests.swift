#if canImport(UIKit) && !canImport(sitescopeCore)
import XCTest
import UIKit
import RealityKit
@testable import sitescope

@MainActor final class SpatialImageAssetTests: XCTestCase {
    func testSavedImageLoadsAsTextureWithSourceDimensions() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 32), format: format).image { context in
            UIColor.systemMint.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
        }
        let data = try XCTUnwrap(image.pngData())
        let texture = try await SpatialImageAsset.loadTexture(data)
        XCTAssertEqual(texture.width, 64)
        XCTAssertEqual(texture.height, 32)
    }

    func testLargeSavedImageUsesBoundedDisplayTexture() async throws {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:1600,height:800),format:format).image { context in
            UIColor.systemBlue.setFill();context.fill(CGRect(x:0,y:0,width:1600,height:800))
        }
        let texture=try await SpatialImageAsset.loadTexture(XCTUnwrap(image.pngData()))
        XCTAssertEqual(texture.width,1024);XCTAssertEqual(texture.height,512)
    }

    func testInvalidAndOversizeImagesAreRejected() async {
        for data in [Data([0, 1, 2, 3]), Data(repeating: 0, count: 30_000_001)] {
            do {
                _ = try await SpatialImageAsset.loadTexture(data)
                XCTFail("Invalid image must not create a texture")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains("could not be loaded"))
            }
        }
    }

    func testCancelledLoadDoesNotPublishTexture() async throws {
        let task = Task { @MainActor in
            try await SpatialImageAsset.loadTexture(Data([0, 1, 2, 3]))
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled load must not return a texture")
        } catch is CancellationError {
            // Cancellation wins before image decoding or GPU allocation begins.
        } catch {
            XCTFail("Expected cancellation, received \(error)")
        }
    }
}
#endif
