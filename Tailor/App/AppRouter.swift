import Foundation
import Combine

final class AppRouter: ObservableObject {
    @Published private(set) var path: [AppRoute] = [.welcome]

    var currentRoute: AppRoute { path.last ?? .welcome }

    func navigate(to route: AppRoute) {
        if let existing = path.firstIndex(of: route) {
            path = Array(path.prefix(through: existing))
        } else {
            path.append(route)
        }
    }

    func goBack() {
        guard path.count > 1 else { return }
        path.removeLast()
    }

    func reset() { path = [.welcome] }
}
