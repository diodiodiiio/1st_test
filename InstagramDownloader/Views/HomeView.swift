import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var mediaViewModel = MediaViewModel()
    @State private var showDownloadConfirm = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let user = authViewModel.currentUser {
                    ProfileHeaderView(user: user, mediaCount: mediaViewModel.mediaItems.count)
                }

                MediaGridView(viewModel: mediaViewModel)

                if !mediaViewModel.mediaItems.isEmpty {
                    downloadBar
                }
            }
            .navigationTitle("投稿一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ログアウト") {
                        authViewModel.logout()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await mediaViewModel.fetchAllPosts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(mediaViewModel.isLoading)
                }
            }
            .task {
                guard let user = authViewModel.currentUser,
                      let token = InstagramAuthService.shared.accessToken else { return }
                mediaViewModel.configure(userId: user.id, accessToken: token)
                await mediaViewModel.fetchAllPosts()
            }
            .alert("すべてダウンロード", isPresented: $showDownloadConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("ダウンロード") {
                    Task { await mediaViewModel.downloadAll() }
                }
            } message: {
                Text("未ダウンロードの \(mediaViewModel.mediaItems.filter { !mediaViewModel.downloadService.isCompleted($0.id) }.count) 件をカメラロールに保存します。")
            }
            .alert("完了", isPresented: .init(
                get: { mediaViewModel.successMessage != nil },
                set: { if !$0 { mediaViewModel.successMessage = nil } }
            )) {
                Button("OK") { mediaViewModel.successMessage = nil }
            } message: {
                Text(mediaViewModel.successMessage ?? "")
            }
        }
    }

    var downloadBar: some View {
        VStack(spacing: 8) {
            if mediaViewModel.isDownloadingAll {
                VStack(spacing: 4) {
                    ProgressView(
                        value: Double(mediaViewModel.downloadProgress.completed),
                        total: Double(mediaViewModel.downloadProgress.total)
                    )
                    Text("\(mediaViewModel.downloadProgress.completed) / \(mediaViewModel.downloadProgress.total) 件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Button {
                showDownloadConfirm = true
            } label: {
                Label(
                    "すべてダウンロード（\(mediaViewModel.mediaItems.count) 件）",
                    systemImage: "arrow.down.to.line"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(mediaViewModel.isDownloadingAll ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(mediaViewModel.isDownloadingAll)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }
}
