import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "833AB4"), Color(hex: "FD1D1D"), Color(hex: "FCAF45")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "camera")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 24)

            Text("Instagram Downloader")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Instagramの投稿を一括ダウンロード")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                Button {
                    // Login handled in the button label via presentationContextProvider
                } label: {
                    EmptyView()
                }

                LoginButton(authViewModel: authViewModel)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 4) {
                    Text("Instagram Graph API を使用")
                    Text("ビジネス / クリエイターアカウントが必要です")
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
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                }
                Text(authViewModel.isLoading ? "ログイン中..." : "Instagramでログイン")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "833AB4"), Color(hex: "FD1D1D"), Color(hex: "FCAF45")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
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
