import Mantis
import UIKit
import XCTest
@testable import TailorMantisAdapter

final class TailorMantisCropEnvelopeTests: XCTestCase {
    func testEnvelopeRoundTripsAndReplaysIdenticalPixelsFromOriginal() throws {
        let original = makePatternImage(width: 640, height: 480)
        let cropInfo = CropInfo(
            translation: CGPoint(x: 18, y: -12),
            rotation: .pi / 18,
            scaleX: -1.2,
            scaleY: 1.2,
            cropSize: CGSize(width: 220, height: 180),
            imageViewSize: CGSize(width: 320, height: 240),
            cropRegion: CropRegion(
                topLeft: CGPoint(x: 30, y: 20),
                topRight: CGPoint(x: 250, y: 20),
                bottomLeft: CGPoint(x: 30, y: 200),
                bottomRight: CGPoint(x: 250, y: 200)
            )
        )
        let direct = try XCTUnwrap(Mantis.crop(image: original, by: cropInfo))
        let envelope = try TailorMantisCropEnvelope(cropInfo: cropInfo)
        let persisted = try JSONEncoder().encode(envelope)
        let reopened = try JSONDecoder().decode(TailorMantisCropEnvelope.self, from: persisted)
        let replayed = try reopened.render(original: original)

        XCTAssertEqual(reopened, envelope)
        XCTAssertEqual(replayed.size, direct.size)
        XCTAssertEqual(replayed.pngData(), direct.pngData(), "Reopen must replay the same original pixels, not a saved derivative")
        XCTAssertLessThan(envelope.cropInfoJSON.count, 4_096, "The payload must remain geometry, not encoded personal image bytes")
        XCTAssertFalse(envelope.cropInfoJSON.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    func testEnvelopeRejectsUnknownSchemaPackageAndProvider() throws {
        let info = CropInfo(
            translation: .zero,
            rotation: 0,
            scaleX: 1,
            scaleY: 1,
            cropSize: CGSize(width: 100, height: 100),
            imageViewSize: CGSize(width: 200, height: 200),
            cropRegion: CropRegion(topLeft: .zero, topRight: CGPoint(x: 100, y: 0), bottomLeft: CGPoint(x: 0, y: 100), bottomRight: CGPoint(x: 100, y: 100))
        )
        let valid = try TailorMantisCropEnvelope(cropInfo: info)

        var unknownSchema = valid
        unknownSchema.schemaVersion = 2
        XCTAssertThrowsError(try unknownSchema.decodedCropInfo()) {
            XCTAssertEqual($0 as? TailorMantisCropEnvelopeError, .unsupportedSchema(2))
        }

        var unknownPackage = valid
        unknownPackage.packageVersion = "4.0.0"
        XCTAssertThrowsError(try unknownPackage.decodedCropInfo()) {
            XCTAssertEqual($0 as? TailorMantisCropEnvelopeError, .unsupportedPackageVersion("4.0.0"))
        }

        var unknownProvider = valid
        unknownProvider.provider = "FlattenedBitmap"
        XCTAssertThrowsError(try unknownProvider.decodedCropInfo()) {
            XCTAssertEqual($0 as? TailorMantisCropEnvelopeError, .unsupportedProvider("FlattenedBitmap"))
        }
    }

    private func makePatternImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height / 2))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: width / 2, y: height / 2, width: width / 2, height: height / 2))
        }
    }
}
