import Foundation
import AuthenticationServices
import CryptoKit
import Security

enum AuthError: LocalizedError {
    case invalidURL
    case noAuthorizationCode
    case noData
    case notAuthenticated
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "認証URLが無効です"
        case .noAuthorizationCode: return "認証コードが取得できませんでした"
        case .noData: return "サーバーからデータを受信できませんでした"
        case .notAuthenticated: return "サインインが必要です"
        case .tokenExchangeFailed(let reason): return "トークン交換に失敗しました: \(reason)"
        }
    }
}

/// Google OAuth 2.0 (Authorization Code + PKCE) for the YouTube Data API.
///
/// Installed-app clients do not use a client secret; PKCE protects the code
/// exchange. Configure `clientID` with your iOS OAuth client from the Google
/// Cloud Console, and add the matching reversed-client-id URL scheme to
/// Info.plist (see README).
class GoogleAuthService: NSObject, ObservableObject {
    static let shared = GoogleAuthService()

    /// Configure this with the iOS OAuth client ID from Google Cloud Console,
    /// e.g. "1234567890-abcdefg.apps.googleusercontent.com".
    var clientID: String = "YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com"

    private let scope = "https://www.googleapis.com/auth/youtube.readonly"
    private let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"

    private let accessTokenKey = "yt_access_token"
    private let refreshTokenKey = "yt_refresh_token"
    private let expiryKey = "yt_token_expiry"

    @Published var isSignedIn = false

    private var authSession: ASWebAuthenticationSession?
    private var currentVerifier: String?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        super.init()
        self.isSignedIn = UserDefaults.standard.string(forKey: refreshTokenKey) != nil
    }

    /// The reversed-client-id URL scheme Google expects for iOS clients,
    /// e.g. "com.googleusercontent.apps.1234567890-abcdefg".
    var reversedClientID: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    private var redirectURI: String {
        "\(reversedClientID):/oauth2redirect"
    }

    // MARK: - Sign in

    func authenticate(presentationContextProvider: ASWebAuthenticationPresentationContextProviding,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        let verifier = Self.makeCodeVerifier()
        currentVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components.url else {
            completion(.failure(AuthError.invalidURL))
            return
        }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: reversedClientID
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

    private func exchangeCodeForToken(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let params = [
            "client_id": clientID,
            "code": code,
            "code_verifier": currentVerifier ?? "",
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        postToken(params: params) { [weak self] result in
            switch result {
            case .success(let token):
                DispatchQueue.main.async {
                    self?.save(token: token)
                    self?.isSignedIn = true
                    completion(.success(()))
                }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Token access / refresh

    /// Returns a currently valid access token, refreshing it if it has
    /// expired (or is about to). Throws `AuthError.notAuthenticated` if the
    /// user has not signed in.
    func validAccessToken() async throws -> String {
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: accessTokenKey),
           let expiry = defaults.object(forKey: expiryKey) as? Date,
           expiry.timeIntervalSinceNow > 60 {
            return token
        }
        guard let refreshToken = defaults.string(forKey: refreshTokenKey) else {
            throw AuthError.notAuthenticated
        }
        let token = try await refresh(using: refreshToken)
        return token.accessToken
    }

    private func refresh(using refreshToken: String) async throws -> TokenResponse {
        let params = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        return try await withCheckedThrowingContinuation { continuation in
            postToken(params: params) { [weak self] result in
                switch result {
                case .success(var token):
                    // A refresh response omits refresh_token; keep the old one.
                    if token.refreshToken == nil { token.refreshToken = refreshToken }
                    DispatchQueue.main.async { self?.save(token: token) }
                    continuation.resume(returning: token)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func postToken(params: [String: String], completion: @escaping (Result<TokenResponse, Error>) -> Void) {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(AuthError.noData))
                return
            }
            do {
                let token = try JSONDecoder().decode(TokenResponse.self, from: data)
                completion(.success(token))
            } catch {
                let reason = String(data: data, encoding: .utf8) ?? error.localizedDescription
                completion(.failure(AuthError.tokenExchangeFailed(reason)))
            }
        }.resume()
    }

    // MARK: - Persistence

    private func save(token: TokenResponse) {
        let defaults = UserDefaults.standard
        defaults.set(token.accessToken, forKey: accessTokenKey)
        if let refresh = token.refreshToken {
            defaults.set(refresh, forKey: refreshTokenKey)
        }
        let expiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        defaults.set(expiry, forKey: expiryKey)
    }

    func logout() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: accessTokenKey)
        defaults.removeObject(forKey: refreshTokenKey)
        defaults.removeObject(forKey: expiryKey)
        isSignedIn = false
    }

    // MARK: - PKCE helpers

    static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    struct TokenResponse: Codable {
        let accessToken: String
        var refreshToken: String?
        let expiresIn: Int
        let tokenType: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }
    }
}

extension Data {
    /// Base64URL without padding, per RFC 7636 (PKCE).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    /// Allowed characters for form-url-encoded query values.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
