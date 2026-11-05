#if canImport(UIKit) && !canImport(sitescopeCore)
import XCTest
import CoreVideo
import ImageIO
import UIKit
@testable import sitescope

final class ScanGuideImageTests: XCTestCase {
    /// Synthetic camera-sized BGRA pixels, exclusively for the image encoder test.
    private func colorFrame() throws -> CVPixelBuffer {
        var buffer:CVPixelBuffer?
        let status=CVPixelBufferCreate(kCFAllocatorDefault,640,480,kCVPixelFormatType_32BGRA,nil,&buffer)
        XCTAssertEqual(status,kCVReturnSuccess)
        let frame=try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(frame,[])
        defer { CVPixelBufferUnlockBaseAddress(frame,[]) }
        let base=try XCTUnwrap(CVPixelBufferGetBaseAddress(frame)).assumingMemoryBound(to:UInt8.self)
        let stride=CVPixelBufferGetBytesPerRow(frame)
        for y in 0..<480 {
            for x in 0..<640 {
                let offset=y*stride+x*4
                base[offset]=UInt8(x*255/639)
                base[offset+1]=UInt8(y*255/479)
                base[offset+2]=UInt8((639-x)*255/639)
                base[offset+3]=255
            }
        }
        return frame
    }

    func testCaptureProducesBoundedPortraitJPEGAndDisplayableThumbnail() async throws {
        let frame=try colorFrame()
        let result=await ScanGuideImage.capture(frame)
        let encoded=try XCTUnwrap(result)
        let jpeg=try XCTUnwrap(Data(base64Encoded:encoded))
        XCTAssertLessThanOrEqual(jpeg.count,65_536)
        XCTAssertEqual(Array(jpeg.prefix(2)),[0xff,0xd8])
        let source=try XCTUnwrap(CGImageSourceCreateWithData(jpeg as CFData,nil))
        let decoded=try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
        // Camera buffers are landscape; capture rotates the actual pixels for portrait viewing.
        XCTAssertEqual(decoded.width,384)
        XCTAssertEqual(decoded.height,512)
        let thumbnail=try XCTUnwrap(ScanGuideImage.thumbnail(encoded))
        let pixels=try XCTUnwrap(thumbnail.cgImage)
        XCTAssertEqual(pixels.width,decoded.width)
        XCTAssertEqual(pixels.height,decoded.height)
        XCTAssertEqual(thumbnail.imageOrientation,.up)
    }

    func testThumbnailRejectsInvalidOrOversizedData() {
        XCTAssertNil(ScanGuideImage.thumbnail("not base64!"))
        XCTAssertNil(ScanGuideImage.thumbnail(Data("not an image".utf8).base64EncodedString()))
        XCTAssertNil(ScanGuideImage.thumbnail(Data(repeating:0,count:65_537).base64EncodedString()))
    }
}
#endif
