import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "FF0000"))
                    .frame(width: 100, height: 100)
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 24)

            Text("YouTube Liked Extractor")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("いいねした動画を期間で抽出・分類")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                LoginButton(authViewModel: authViewModel)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 4) {
                    Text("YouTube Data API v3 を使用")
                    Text("いいね動画の読み取り権限のみを要求します")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}

struct LoginButton: View, ASWebAuthenticationPresentationContextProviding {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        Button {
            authViewModel.login(presentationContext: self)
        } label: {
            HStack(spacing: 12) {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.body.weight(.semibold))
                }
                Text(authViewModel.isLoading ? "サインイン中..." : "Googleでサインイン")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "FF0000"))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(authViewModel.isLoading)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
