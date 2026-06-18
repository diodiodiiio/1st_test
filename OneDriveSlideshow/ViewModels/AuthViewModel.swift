import SwiftUI
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private(set) var accessToken: String?

    init() {
        isSignedIn = MSAuthService.shared.currentAccount != nil
        if isSignedIn {
            Task { await refreshToken() }
        }
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let vc = rootViewController() else {
            errorMessage = "表示できるウィンドウが見つかりません"
            return
        }

        do {
            accessToken = try await MSAuthService.shared.signIn(presentingViewController: vc)
            isSignedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? MSAuthService.shared.signOut()
        accessToken = nil
        isSignedIn = false
        ImageCacheService.shared.clearAll()
    }

    func validToken() async throws -> String {
        if let token = accessToken { return token }
        let token = try await MSAuthService.shared.acquireTokenSilently()
        accessToken = token
        return token
    }

    private func refreshToken() async {
        do {
            accessToken = try await MSAuthService.shared.acquireTokenSilently()
        } catch {
            isSignedIn = false
        }
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
