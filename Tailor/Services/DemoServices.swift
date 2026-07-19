import Foundation

actor InMemoryArchiveRepository: ArchiveRepository {
    private var documents: [UUID: ArchiveDocument] = [:]
    func save(profile: PetProfile) async throws {
        let existing = documents[profile.id]
        documents[profile.id] = ArchiveDocument(profile: profile, photos: existing?.photos ?? [], chapters: existing?.chapters ?? [])
    }
    func profile(id: UUID) async throws -> PetProfile? { documents[id]?.profile }
    func allProfiles() async throws -> [PetProfile] { documents.values.map(\.profile).sorted { $0.name < $1.name } }
    func deleteArchive(id: UUID) async throws { documents.removeValue(forKey: id) }
    func save(document: ArchiveDocument) async throws { documents[document.id] = document }
    func document(id: UUID) async throws -> ArchiveDocument? { documents[id] }
}

struct DemoPetScanService: PetScanServicing {
    func scan(profile: PetProfile) async throws -> [ArchivePhoto] {
        try await Task.sleep(for: .milliseconds(250))
        return (0..<3).map { index in
            ArchivePhoto(id: UUID(), assetLocalIdentifier: "demo-\(index)", decision: index == 0 ? .selected : .needsReview, confidence: 0.96 - Double(index) * 0.18, createdAt: .now)
        }
    }
}

actor DemoPurchaseService: PurchaseServicing {
    private var entitled = false
    func purchaseUnlock() async throws -> PurchaseState {
        let arguments = ProcessInfo.processInfo.arguments
        let state = arguments.firstIndex(of: "-uiDemoState").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        } ?? ""
        switch state {
        case "purchase-cancelled": return .cancelled
        case "purchase-pending": return .pending
        case "purchase-failed": return .failed("The Tailor unlock is not available right now.")
        default:
            entitled = true
            return .entitled
        }
    }
    func restorePurchases() async throws -> PurchaseState { entitled ? .restored : .idle }
    func isEntitled() async -> Bool { entitled }
}

struct DemoPDFExporter: PDFExporting {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL {
        try await Task.sleep(for: .milliseconds(150))
        let output = URL.documentsDirectory.appending(path: "\(profile.id.uuidString)-life-archive.pdf")
        try Data("%PDF-1.4\n% Tailor UI test archive\n%%EOF\n".utf8).write(to: output, options: .atomic)
        return output
    }
}
