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
}

protocol PurchaseServicing: Sendable {
    func purchaseUnlock() async throws -> PurchaseState
    func restorePurchases() async throws -> PurchaseState
    func isEntitled() async -> Bool
}

protocol PDFExporting: Sendable {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL
}
