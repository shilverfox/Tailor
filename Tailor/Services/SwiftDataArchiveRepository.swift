import Foundation
import SwiftData

@Model
final class StoredPetProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var speciesRawValue: String
    var arrivalYear: Int?
    var departureYear: Int
    var lifecycleRawValue: String
    var referenceIdentifiersData: Data
    var albumStyleRawValue: String
    var archivePhotosData: Data
    var chaptersData: Data
    var scanCheckpointData: Data?
    var scanAuditMetricsData: Data?
    var memoryBookData: Data?
    var exportRecordsData: Data?
    /// Aggregate local-only recognition feedback. Optional preserves migration
    /// compatibility with archives saved before this field existed.
    var recognitionFeedbackData: Data?
    var updatedAt: Date

    init(profile: PetProfile) {
        id = profile.id
        name = profile.name
        speciesRawValue = profile.species.rawValue
        arrivalYear = profile.arrivalYear
        departureYear = profile.departureYear
        lifecycleRawValue = profile.lifecycle.rawValue
        referenceIdentifiersData = (try? JSONEncoder().encode(profile.referenceAssetIdentifiers)) ?? Data()
        albumStyleRawValue = profile.albumStyle.rawValue
        archivePhotosData = Data()
        chaptersData = Data()
        scanCheckpointData = nil
        scanAuditMetricsData = nil
        memoryBookData = nil
        exportRecordsData = nil
        recognitionFeedbackData = nil
        updatedAt = .now
    }

    func apply(_ profile: PetProfile) {
        name = profile.name
        speciesRawValue = profile.species.rawValue
        arrivalYear = profile.arrivalYear
        departureYear = profile.departureYear
        lifecycleRawValue = profile.lifecycle.rawValue
        referenceIdentifiersData = (try? JSONEncoder().encode(profile.referenceAssetIdentifiers)) ?? Data()
        albumStyleRawValue = profile.albumStyle.rawValue
        updatedAt = .now
    }

    var domainProfile: PetProfile {
        PetProfile(
            id: id,
            name: name,
            species: PetSpecies(rawValue: speciesRawValue) ?? .dog,
            arrivalYear: arrivalYear,
            departureYear: departureYear,
            lifecycle: ProfileLifecycle(rawValue: lifecycleRawValue) ?? .draft,
            referenceAssetIdentifiers: (try? JSONDecoder().decode([String].self, from: referenceIdentifiersData)) ?? [],
            albumStyle: AlbumStyle(rawValue: albumStyleRawValue) ?? .warmPaper
        )
    }

    var archiveDocument: ArchiveDocument {
        ArchiveDocument(
            profile: domainProfile,
            photos: (try? JSONDecoder().decode([ArchivePhoto].self, from: archivePhotosData)) ?? [],
            chapters: (try? JSONDecoder().decode([Chapter].self, from: chaptersData)) ?? [],
            scanCheckpoint: scanCheckpointData.flatMap { try? JSONDecoder().decode(ScanCheckpoint.self, from: $0) },
            scanAuditMetrics: scanAuditMetricsData.flatMap { try? JSONDecoder().decode(ScanAuditMetrics.self, from: $0) } ?? .init(),
            memoryBook: memoryBookData.flatMap { try? JSONDecoder().decode(MemoryBookDocument.self, from: $0) },
            exportRecords: exportRecordsData.flatMap { try? JSONDecoder().decode([MemoryBookExportRecord].self, from: $0) } ?? [],
            recognitionFeedback: recognitionFeedbackData.flatMap { try? JSONDecoder().decode(PetRecognitionFeedbackSummary.self, from: $0) },
            updatedAt: updatedAt
        )
    }

    func apply(_ document: ArchiveDocument) {
        apply(document.profile)
        archivePhotosData = (try? JSONEncoder().encode(document.photos)) ?? Data()
        chaptersData = (try? JSONEncoder().encode(document.chapters)) ?? Data()
        scanCheckpointData = try? document.scanCheckpoint.map { try JSONEncoder().encode($0) }
        scanAuditMetricsData = try? JSONEncoder().encode(document.scanAuditMetrics)
        memoryBookData = try? document.memoryBook.map { try JSONEncoder().encode($0) }
        exportRecordsData = try? JSONEncoder().encode(document.exportRecords)
        // Recompute at the persistence boundary so direct domain mutations
        // cannot save a stale aggregate beside the user's photo decisions.
        recognitionFeedbackData = try? JSONEncoder().encode(.make(from: document.photos) as PetRecognitionFeedbackSummary)
        updatedAt = document.updatedAt
    }
}

@ModelActor
actor SwiftDataArchiveRepository: ArchiveRepository {
    func save(profile: PetProfile) throws {
        let profileID = profile.id
        let descriptor = FetchDescriptor<StoredPetProfile>(predicate: #Predicate { $0.id == profileID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(profile)
        } else {
            modelContext.insert(StoredPetProfile(profile: profile))
        }
        try modelContext.save()
    }

    func profile(id: UUID) throws -> PetProfile? {
        let descriptor = FetchDescriptor<StoredPetProfile>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.domainProfile
    }

    func allProfiles() throws -> [PetProfile] {
        try modelContext.fetch(FetchDescriptor<StoredPetProfile>())
            .map(\.domainProfile)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func deleteArchive(id: UUID) throws {
        let descriptor = FetchDescriptor<StoredPetProfile>(predicate: #Predicate { $0.id == id })
        if let profile = try modelContext.fetch(descriptor).first {
            modelContext.delete(profile)
            try modelContext.save()
        }
    }

    func save(document: ArchiveDocument) throws {
        let documentID = document.id
        let descriptor = FetchDescriptor<StoredPetProfile>(predicate: #Predicate { $0.id == documentID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(document)
        } else {
            let stored = StoredPetProfile(profile: document.profile)
            stored.apply(document)
            modelContext.insert(stored)
        }
        try modelContext.save()
    }

    func document(id: UUID) throws -> ArchiveDocument? {
        let descriptor = FetchDescriptor<StoredPetProfile>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.archiveDocument
    }
}
