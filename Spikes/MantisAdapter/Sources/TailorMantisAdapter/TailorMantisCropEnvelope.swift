import Foundation
import Mantis
import UIKit

/// Disposable M7 spike contract. It deliberately stores only Mantis geometry;
/// the caller must retain and provide Tailor's original PhotoKit image.
public struct TailorMantisCropEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let supportedPackageVersion = "3.1.0"
    public static let provider = "Mantis"

    public var schemaVersion: Int
    public var packageVersion: String
    public var provider: String
    public var cropInfoJSON: Data

    public init(cropInfo: CropInfo) throws {
        schemaVersion = Self.currentSchemaVersion
        packageVersion = Self.supportedPackageVersion
        provider = Self.provider
        cropInfoJSON = try JSONEncoder().encode(cropInfo)
    }

    public func decodedCropInfo() throws -> CropInfo {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw TailorMantisCropEnvelopeError.unsupportedSchema(schemaVersion)
        }
        guard packageVersion == Self.supportedPackageVersion else {
            throw TailorMantisCropEnvelopeError.unsupportedPackageVersion(packageVersion)
        }
        guard provider == Self.provider else {
            throw TailorMantisCropEnvelopeError.unsupportedProvider(provider)
        }
        return try JSONDecoder().decode(CropInfo.self, from: cropInfoJSON)
    }

    /// Replays the persisted crop against the caller-provided original. No
    /// flattened bitmap or personal photo bytes are retained by the envelope.
    public func render(original: UIImage, maxImagePixelCount: Int = 0) throws -> UIImage {
        let cropInfo = try decodedCropInfo()
        guard let output = Mantis.crop(image: original, by: cropInfo, maxImagePixelCount: maxImagePixelCount) else {
            throw TailorMantisCropEnvelopeError.renderFailed
        }
        return output
    }
}

public enum TailorMantisCropEnvelopeError: Error, Equatable {
    case unsupportedSchema(Int)
    case unsupportedPackageVersion(String)
    case unsupportedProvider(String)
    case renderFailed
}
