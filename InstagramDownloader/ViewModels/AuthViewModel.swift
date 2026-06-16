import Foundation
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: InstagramUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: InstagramAuthService
    private let apiService: InstagramAPIServiceProtocol

    init(
        authService: InstagramAuthService = .shared,
        apiService: InstagramAPIServiceProtocol = InstagramAPIService.shared
    ) {
        self.authService = authService
        self.apiService = apiService

        if let token = authService.loadSavedToken() {
            isAuthenticated = true
            Task { await fetchCurrentUser(token: token) }
        }
    }

    func login(presentationContext: ASWebAuthenticationPresentationContextProviding) {
        isLoading = true
        errorMessage = nil

        authService.authenticate(presentationContextProvider: presentationContext) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let token):
                    self?.isAuthenticated = true
                    await self?.fetchCurrentUser(token: token)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func logout() {
        authService.logout()
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }

    private func fetchCurrentUser(token: String) async {
        do {
            currentUser = try await apiService.fetchUserProfile(userId: "me", accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
