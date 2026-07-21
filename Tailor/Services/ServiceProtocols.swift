import Foundation

protocol ArchiveRepository: Sendable {
    func save(profile: PetProfile) async throws
    func profile(id: UUID) async throws -> PetProfile?
    func allProfiles() async throws -> [PetProfile]
    func deleteArchive(id: UUID) async throws
    func save(document: ArchiveDocument) async throws
    func document(id: UUID) async throws -> ArchiveDocument?
}

protocol PetScanServicing: Sendable {
    func scan(profile: PetProfile) async throws -> [ArchivePhoto]
    func scan(
        profile: PetProfile,
        checkpoint: ScanCheckpoint?,
        onProgress: @escaping @Sendable (ScanCheckpoint) async -> Void
    ) async throws -> [ArchivePhoto]
    /// Removes private, local matching material when the user deletes an
    /// archive. Lightweight test scanners retain the no-op default.
    func deleteLocalIndex(profileID: UUID) async
}

extension PetScanServicing {
    /// Default behavior keeps lightweight scanners and test doubles compatible. The
    /// production PhotoKit scanner overrides this to publish durable checkpoints.
    func scan(
        profile: PetProfile,
        checkpoint: ScanCheckpoint?,
        onProgress: @escaping @Sendable (ScanCheckpoint) async -> Void
    ) async throws -> [ArchivePhoto] {
        let candidates = try await scan(profile: profile)
        await onProgress(ScanCheckpoint(nextAssetIndex: 1, totalAssets: 1, candidates: candidates))
        return candidates
    }

    func deleteLocalIndex(profileID: UUID) async {}
}

protocol PurchaseServicing: Sendable {
    func unlockDisplayPrice() async -> String?
    func purchaseUnlock() async throws -> PurchaseState
    func restorePurchases() async throws -> PurchaseState
    func isEntitled() async -> Bool
}

extension PurchaseServicing {
    func unlockDisplayPrice() async -> String? { nil }
}

protocol PDFExporting: Sendable {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL
    /// Export the exact page model produced by the editor. Existing exporters get
    /// a compatibility default while production can override it for one-to-one output.
    func export(document: MemoryBookDocument) async throws -> URL
    /// Rendering progress is emitted after each completed page. The default keeps
    /// compatibility exporters honest about their start/end state.
    func export(document: MemoryBookDocument, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> URL
}

extension PDFExporting {
    func export(document: MemoryBookDocument) async throws -> URL {
        try await export(profile: document.profile, photos: document.photos, chapters: document.chapters, pageSize: document.pageSize)
    }
    func export(document: MemoryBookDocument, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> URL {
        progress(0, document.pages.count)
        let output = try await export(document: document)
        progress(document.pages.count, document.pages.count)
        return output
    }
}

protocol VideoExporting: Sendable {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], duration: TimeInterval) async throws -> URL
}
