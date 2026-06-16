import Foundation
import AuthenticationServices

enum AuthError: LocalizedError {
    case invalidURL
    case noAuthorizationCode
    case noData
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "認証URLが無効です"
        case .noAuthorizationCode: return "認証コードが取得できませんでした"
        case .noData: return "サーバーからデータを受信できませんでした"
        case .tokenExchangeFailed(let reason): return "トークン交換に失敗しました: \(reason)"
        }
    }
}

class InstagramAuthService: NSObject, ObservableObject {
    static let shared = InstagramAuthService()

    // Configure these in your Facebook Developer Console
    var clientId: String = "YOUR_INSTAGRAM_APP_ID"
    var clientSecret: String = "YOUR_INSTAGRAM_APP_SECRET"
    var redirectUri: String = "instagramdownloader://auth/callback"

    private let scope = "instagram_basic,instagram_content_publish,pages_show_list"
    private let baseAuthURL = "https://api.instagram.com/oauth/authorize"
    private let tokenURL = "https://api.instagram.com/oauth/access_token"
    private let tokenKey = "instagram_access_token"

    @Published var accessToken: String?

    private var authSession: ASWebAuthenticationSession?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        super.init()
    }

    func authenticate(presentationContextProvider: ASWebAuthenticationPresentationContextProviding,
                      completion: @escaping (Result<String, Error>) -> Void) {
        var components = URLComponents(string: baseAuthURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "response_type", value: "code")
        ]

        guard let url = components.url else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "instagramdownloader"
        ) { [weak self] callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let callbackURL = callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?
                    .value else {
                completion(.failure(AuthError.noAuthorizationCode))
                return
            }

            self?.exchangeCodeForToken(code: code, completion: completion)
        }

        authSession?.presentationContextProvider = presentationContextProvider
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    private func exchangeCodeForToken(code: String, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
            "code": code
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(AuthError.noData)) }
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                DispatchQueue.main.async {
                    self.saveToken(tokenResponse.accessToken)
                    completion(.success(tokenResponse.accessToken))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(AuthError.tokenExchangeFailed(error.localizedDescription)))
                }
            }
        }.resume()
    }

    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        accessToken = token
    }

    func loadSavedToken() -> String? {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        accessToken = token
        return token
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        accessToken = nil
    }

    private struct TokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let userId: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case userId = "user_id"
        }
    }
}
