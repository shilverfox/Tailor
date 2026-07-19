import Foundation
import Combine
import SwiftData

enum ProductionStorageUnavailableError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "Tailor couldn’t open its private on-device archive. Your photos were not changed. Please restart the app and try again."
    }
}

/// Explicit production-safe fallback. It never manufactures photos, purchase
/// entitlement, exports, or persisted archives when SwiftData cannot open.
actor UnavailableArchiveRepository: ArchiveRepository {
    func save(profile: PetProfile) throws { throw ProductionStorageUnavailableError.unavailable }
    func profile(id: UUID) throws -> PetProfile? { throw ProductionStorageUnavailableError.unavailable }
    func allProfiles() throws -> [PetProfile] { throw ProductionStorageUnavailableError.unavailable }
    func deleteArchive(id: UUID) throws { throw ProductionStorageUnavailableError.unavailable }
    func save(document: ArchiveDocument) throws { throw ProductionStorageUnavailableError.unavailable }
    func document(id: UUID) throws -> ArchiveDocument? { throw ProductionStorageUnavailableError.unavailable }
}

struct UnavailableProductionScanner: PetScanServicing {
    func scan(profile: PetProfile) async throws -> [ArchivePhoto] { throw ScanFailure.unavailable }
}

struct UnavailableProductionPurchase: PurchaseServicing {
    func purchaseUnlock() async throws -> PurchaseState { throw ProductionStorageUnavailableError.unavailable }
    func restorePurchases() async throws -> PurchaseState { throw ProductionStorageUnavailableError.unavailable }
    func isEntitled() async -> Bool { false }
}

struct UnavailableProductionPDFExporter: PDFExporting {
    func export(profile: PetProfile, photos: [ArchivePhoto], chapters: [Chapter], pageSize: PDFPageSize) async throws -> URL { throw ProductionStorageUnavailableError.unavailable }
}

/// Composition root. Production integrations replace only the demo services.
final class AppContainer: ObservableObject {
    let repository: any ArchiveRepository
    let scanner: any PetScanServicing
    let purchase: any PurchaseServicing
    let pdfExporter: any PDFExporting
    let videoExporter: any VideoExporting
    let router: AppRouter

    init(
        repository: any ArchiveRepository,
        scanner: any PetScanServicing,
        purchase: any PurchaseServicing,
        pdfExporter: any PDFExporting,
        videoExporter: any VideoExporting = LocalVideoExporter(),
        router: AppRouter = AppRouter()
    ) {
        self.repository = repository
        self.scanner = scanner
        self.purchase = purchase
        self.pdfExporter = pdfExporter
        self.videoExporter = videoExporter
        self.router = router
    }

    static let demo = AppContainer(
        repository: InMemoryArchiveRepository(),
        scanner: DemoPetScanService(),
        purchase: DemoPurchaseService(),
        pdfExporter: DemoPDFExporter()
    )

    static func makeProduction() -> AppContainer {
        do {
            let modelContainer = try ModelContainer(for: StoredPetProfile.self)
            return AppContainer(
                repository: SwiftDataArchiveRepository(modelContainer: modelContainer),
                scanner: PhotoKitVisionScanner(),
                purchase: StoreKitPurchaseService(),
                pdfExporter: LocalPDFExporter(),
                videoExporter: LocalVideoExporter()
            )
        } catch {
            assertionFailure("Unable to create Tailor's local archive store: \(error)")
            return AppContainer(
                repository: UnavailableArchiveRepository(),
                scanner: UnavailableProductionScanner(),
                purchase: UnavailableProductionPurchase(),
                pdfExporter: UnavailableProductionPDFExporter(),
                videoExporter: LocalVideoExporter()
            )
        }
    }
}
