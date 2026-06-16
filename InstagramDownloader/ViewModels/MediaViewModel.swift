import Foundation

@MainActor
class MediaViewModel: ObservableObject {
    @Published var mediaItems: [InstagramMedia] = []
    @Published var isLoading = false
    @Published var fetchedCount = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var downloadProgress: (completed: Int, total: Int) = (0, 0)

    private let apiService: InstagramAPIServiceProtocol
    let downloadService: MediaDownloadService

    private var userId: String?
    private var accessToken: String?

    var isDownloadingAll: Bool {
        downloadProgress.total > 0 && downloadProgress.completed < downloadProgress.total
    }

    init(
        apiService: InstagramAPIServiceProtocol = InstagramAPIService.shared,
        downloadService: MediaDownloadService = .shared
    ) {
        self.apiService = apiService
        self.downloadService = downloadService
    }

    func configure(userId: String, accessToken: String) {
        self.userId = userId
        self.accessToken = accessToken
    }

    func fetchAllPosts() async {
        guard let userId = userId, let accessToken = accessToken else { return }

        isLoading = true
        errorMessage = nil
        fetchedCount = 0

        do {
            mediaItems = try await apiService.fetchAllMedia(
                userId: userId,
                accessToken: accessToken,
                progressHandler: { [weak self] count in
                    self?.fetchedCount = count
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func downloadSingle(_ media: InstagramMedia) async {
        await downloadService.downloadMedia(media)
    }

    func downloadAll() async {
        guard !mediaItems.isEmpty else { return }

        let remaining = mediaItems.filter { !downloadService.isCompleted($0.id) }
        guard !remaining.isEmpty else {
            successMessage = "すべてダウンロード済みです"
            return
        }

        downloadProgress = (0, remaining.count)

        await downloadService.downloadAll(remaining) { [weak self] completed, total in
            self?.downloadProgress = (completed, total)
        }

        let failed = downloadService.failedIds.count
        if failed > 0 {
            successMessage = "\(remaining.count - failed) 件をダウンロードしました（\(failed) 件失敗）"
        } else {
            successMessage = "\(remaining.count) 件をカメラロールに保存しました"
        }

        downloadProgress = (0, 0)
    }
}
