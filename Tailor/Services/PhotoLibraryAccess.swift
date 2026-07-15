import Foundation
import Combine
import Photos
import UIKit

@MainActor
final class PhotoLibraryAccess: ObservableObject {
    @Published private(set) var scope: PhotoAccessScope

    init() {
        scope = Self.scope(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func refresh() {
        scope = Self.scope(for: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAccessScope {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let resolvedScope = Self.scope(for: status)
        scope = resolvedScope
        return resolvedScope
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func scope(for status: PHAuthorizationStatus) -> PhotoAccessScope {
        switch status {
        case .authorized: .full
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
        }
    }
}
