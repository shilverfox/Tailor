import Foundation

enum PetSpecies: String, Codable, CaseIterable, Sendable { case dog, cat }
enum ProfileLifecycle: String, Codable, Sendable { case draft, scanning, ready, exported, deleted }
enum PhotoAccessScope: String, Codable, Sendable { case notDetermined, full, limited, denied, restricted }
enum PhotoDecision: String, Codable, Sendable { case selected, needsReview, excluded }
enum AlbumStyle: String, Codable, CaseIterable, Sendable { case warmPaper, quietNight, fieldNotes }
enum PDFPageSize: String, Codable, CaseIterable, Sendable { case letter, a4 }

struct PetProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var species: PetSpecies
    var arrivalYear: Int?
    var departureYear: Int
    var lifecycle: ProfileLifecycle
    var referenceAssetIdentifiers: [String]
    var albumStyle: AlbumStyle

    init(id: UUID = UUID(), name: String, species: PetSpecies, arrivalYear: Int? = nil, departureYear: Int, lifecycle: ProfileLifecycle = .draft, referenceAssetIdentifiers: [String] = [], albumStyle: AlbumStyle = .warmPaper) {
        self.id = id; self.name = name; self.species = species; self.arrivalYear = arrivalYear
        self.departureYear = departureYear; self.lifecycle = lifecycle
        self.referenceAssetIdentifiers = referenceAssetIdentifiers; self.albumStyle = albumStyle
    }
}

struct ArchivePhoto: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var assetLocalIdentifier: String
    var decision: PhotoDecision
    var confidence: Double
    var createdAt: Date?
}

struct Chapter: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var dateLabel: String
    var photoIDs: [UUID]
    var isHidden: Bool
    var sortOrder: Int
}

struct ArchiveDocument: Identifiable, Codable, Equatable, Sendable {
    var profile: PetProfile
    var photos: [ArchivePhoto]
    var chapters: [Chapter]
    var scanCheckpoint: ScanCheckpoint?
    var updatedAt: Date

    var id: UUID { profile.id }

    init(profile: PetProfile, photos: [ArchivePhoto] = [], chapters: [Chapter] = [], scanCheckpoint: ScanCheckpoint? = nil, updatedAt: Date = .now) {
        self.profile = profile
        self.photos = photos
        self.chapters = chapters
        self.scanCheckpoint = scanCheckpoint
        self.updatedAt = updatedAt
    }
}

struct ScanProgress: Codable, Equatable, Sendable { var completedAssets: Int; var totalAssets: Int }
struct ScanCheckpoint: Codable, Equatable, Sendable {
    var nextAssetIndex: Int
    var totalAssets: Int
    var candidates: [ArchivePhoto]

    var progress: ScanProgress { ScanProgress(completedAssets: nextAssetIndex, totalAssets: totalAssets) }
}
enum ScanFailure: Error, Equatable, Sendable { case interrupted, unavailable, insufficientAccess }
enum ScanState: Equatable, Sendable { case idle, running(ScanProgress), paused(ScanProgress), interrupted(ScanProgress), failed(ScanFailure, ScanProgress?), complete }
enum PurchaseState: Equatable, Sendable { case idle, purchasing, cancelled, failed(String), restored, entitled }
enum ExportState: Equatable, Sendable { case idle, choosingPageSize, rendering(Double), failed(String), complete(URL) }
