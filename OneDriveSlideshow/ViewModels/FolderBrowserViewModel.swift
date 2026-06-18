import SwiftUI

@MainActor
final class FolderBrowserViewModel: ObservableObject {
    @Published var items: [DriveItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var navigationPath: [(id: String?, name: String)] = [(id: nil, name: "OneDrive")]

    private let authViewModel: AuthViewModel

    var currentFolderID: String? { navigationPath.last?.id }
    var currentFolderName: String { navigationPath.last?.name ?? "OneDrive" }
    var canGoBack: Bool { navigationPath.count > 1 }

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    func loadItems() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await authViewModel.validToken()
            let all = try await OneDriveAPIService.shared.listChildren(
                itemID: currentFolderID, token: token
            )
            items = all.sorted {
                if $0.isFolder != $1.isFolder { return $0.isFolder }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func navigateInto(item: DriveItem) async {
        navigationPath.append((id: item.id, name: item.name))
        await loadItems()
    }

    func navigateBack() async {
        guard canGoBack else { return }
        navigationPath.removeLast()
        await loadItems()
    }

    func navigateTo(index: Int) async {
        guard index < navigationPath.count else { return }
        navigationPath = Array(navigationPath.prefix(index + 1))
        await loadItems()
    }
}
