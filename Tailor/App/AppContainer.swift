import Foundation
import Combine
import SwiftData

/// Composition root. Production integrations replace only the demo services.
final class AppContainer: ObservableObject {
    let repository: any ArchiveRepository
    let scanner: any PetScanServicing
    let purchase: any PurchaseServicing
    let pdfExporter: any PDFExporting
    let router: AppRouter

    init(
        repository: any ArchiveRepository,
        scanner: any PetScanServicing,
        purchase: any PurchaseServicing,
        pdfExporter: any PDFExporting,
        router: AppRouter = AppRouter()
    ) {
        self.repository = repository
        self.scanner = scanner
        self.purchase = purchase
        self.pdfExporter = pdfExporter
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
                pdfExporter: LocalPDFExporter()
            )
        } catch {
            assertionFailure("Unable to create Tailor's local archive store: \(error)")
            return demo
        }
    }
}
