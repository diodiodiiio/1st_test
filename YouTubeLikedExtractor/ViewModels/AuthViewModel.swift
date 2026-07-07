import Foundation
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: GoogleAuthService

    init(authService: GoogleAuthService = .shared) {
        self.authService = authService
        self.isAuthenticated = authService.isSignedIn
    }

    func login(presentationContext: ASWebAuthenticationPresentationContextProviding) {
        isLoading = true
        errorMessage = nil

        authService.authenticate(presentationContextProvider: presentationContext) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success:
                    self?.isAuthenticated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func logout() {
        authService.logout()
        isAuthenticated = false
        errorMessage = nil
    }
}
