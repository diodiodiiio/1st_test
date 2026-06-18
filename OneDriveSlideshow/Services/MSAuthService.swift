import Foundation
import MSAL

// Replace with your Azure AD app registration values from portal.azure.com
// App registration: "Accounts in any organizational directory and personal Microsoft accounts"
// Redirect URI: msauth.com.yourcompany.onedriveslideshow://auth  (must match Info.plist CFBundleURLSchemes)
private let kClientID = "YOUR_CLIENT_ID_HERE"
private let kAuthority = "https://login.microsoftonline.com/common"
private let kScopes = ["Files.Read", "offline_access"]

enum MSAuthError: Error, LocalizedError {
    case applicationNotInitialized
    case noAccountFound
    case tokenAcquisitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotInitialized: return "認証クライアントの初期化に失敗しました"
        case .noAccountFound: return "サインイン済みのアカウントが見つかりません"
        case .tokenAcquisitionFailed(let msg): return "トークン取得失敗: \(msg)"
        }
    }
}

final class MSAuthService {
    static let shared = MSAuthService()

    private var application: MSALPublicClientApplication?

    private init() {
        do {
            let authority = try MSALAuthority(url: URL(string: kAuthority)!)
            let config = MSALPublicClientApplicationConfig(
                clientId: kClientID,
                redirectUri: nil,
                authority: authority
            )
            application = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("MSAL init failed: \(error)")
        }
    }

    var currentAccount: MSALAccount? {
        guard let app = application else { return nil }
        return try? app.allAccounts().first
    }

    func signIn(presentingViewController: UIViewController) async throws -> String {
        guard let app = application else { throw MSAuthError.applicationNotInitialized }

        let webviewParams = MSALWebviewParameters(authPresentationViewController: presentingViewController)
        let params = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webviewParams)
        params.promptType = .selectAccount

        return try await withCheckedThrowingContinuation { continuation in
            app.acquireToken(with: params) { result, error in
                if let error = error {
                    continuation.resume(throwing: MSAuthError.tokenAcquisitionFailed(error.localizedDescription))
                } else if let token = result?.accessToken {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: MSAuthError.tokenAcquisitionFailed("トークンがありません"))
                }
            }
        }
    }

    func acquireTokenSilently() async throws -> String {
        guard let app = application else { throw MSAuthError.applicationNotInitialized }
        guard let account = currentAccount else { throw MSAuthError.noAccountFound }

        let authority = try MSALAuthority(url: URL(string: kAuthority)!)
        let params = MSALSilentTokenParameters(scopes: kScopes, account: account)
        params.authority = authority

        return try await withCheckedThrowingContinuation { continuation in
            app.acquireTokenSilent(with: params) { result, error in
                if let error = error {
                    continuation.resume(throwing: MSAuthError.tokenAcquisitionFailed(error.localizedDescription))
                } else if let token = result?.accessToken {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: MSAuthError.tokenAcquisitionFailed("トークンがありません"))
                }
            }
        }
    }

    func signOut() throws {
        guard let app = application, let account = currentAccount else { return }
        let params = MSALSignoutParameters(webviewParameters: nil)
        params.signoutFromBrowser = false
        app.signout(with: account, signoutParameters: params) { _, _ in }
    }

    func handleRedirectURL(_ url: URL) -> Bool {
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }
}
