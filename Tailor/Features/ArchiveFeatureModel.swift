import Foundation
import Combine

/// Shared feature state for the future feature views. It deliberately owns no PhotoKit,
/// StoreKit, ML, or PDF implementation details.
@MainActor
final class ArchiveFeatureModel: ObservableObject {
    private let repository: any ArchiveRepository
    private let scanner: any PetScanServicing
    private let purchaseService: any PurchaseServicing
    private let exporter: any PDFExporting

    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var exportState: ExportState = .idle

    init(container: AppContainer) {
        repository = container.repository
        scanner = container.scanner
        purchaseService = container.purchase
        exporter = container.pdfExporter
    }

    func save(_ profile: PetProfile) async throws { try await repository.save(profile: profile) }

    func scan(_ profile: PetProfile) async throws -> [ArchivePhoto] {
        scanState = .running(.init(completedAssets: 0, totalAssets: 1))
        do {
            let candidates = try await scanner.scan(profile: profile)
            scanState = .complete
            return candidates
        } catch {
            scanState = .failed(.unavailable, nil)
            throw error
        }
    }

    func purchase() async {
        purchaseState = .purchasing
        do { purchaseState = try await purchaseService.purchaseUnlock() }
        catch { purchaseState = .failed(error.localizedDescription) }
    }

    func purchaseServiceRestoreForUI() async throws -> PurchaseState {
        let state = try await purchaseService.restorePurchases()
        purchaseState = state
        return state
    }

    func export(profile: PetProfile, chapters: [Chapter], pageSize: PDFPageSize) async {
        exportState = .rendering(0.1)
        do { exportState = .complete(try await exporter.export(profile: profile, photos: [], chapters: chapters, pageSize: pageSize)) }
        catch { exportState = .failed(error.localizedDescription) }
    }
}
