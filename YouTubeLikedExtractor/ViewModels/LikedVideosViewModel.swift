import Foundation

@MainActor
class LikedVideosViewModel: ObservableObject {
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var videos: [LikedVideo] = []
    @Published var isLoading = false
    @Published var fetchedCount = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    /// Currently selected tag filter (`nil` = show all).
    @Published var selectedTag: String?

    private let apiService: YouTubeAPIServiceProtocol
    private let authService: GoogleAuthService
    private let exportService: ExportService

    init(
        apiService: YouTubeAPIServiceProtocol = YouTubeAPIService.shared,
        authService: GoogleAuthService = .shared,
        exportService: ExportService = ExportService()
    ) {
        self.apiService = apiService
        self.authService = authService
        self.exportService = exportService

        // Default to the trailing 30 days.
        let now = Date()
        self.endDate = now
        self.startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
    }

    /// All distinct tags across the fetched videos, sorted, for the filter UI.
    var allTags: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for video in videos where !video.tags.isEmpty {
            for tag in video.tags where seen.insert(tag).inserted {
                ordered.append(tag)
            }
        }
        return ordered.sorted()
    }

    /// Videos after applying the selected tag filter.
    var filteredVideos: [LikedVideo] {
        guard let tag = selectedTag else { return videos }
        return videos.filter { $0.tags.contains(tag) }
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        fetchedCount = 0
        selectedTag = nil

        // Normalize the range to whole days (inclusive).
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: startDate)
        let to = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        do {
            let token = try await authService.validAccessToken()
            videos = try await apiService.fetchLikedVideos(
                from: from,
                to: to,
                regionCode: "JP",
                accessToken: token,
                progressHandler: { [weak self] count in
                    self?.fetchedCount = count
                }
            )
            successMessage = "\(videos.count) 件のいいね動画を抽出しました"
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Exports the currently filtered videos and returns the file URL to share.
    func export(format: ExportService.Format) -> URL? {
        guard !filteredVideos.isEmpty else {
            errorMessage = "エクスポートする動画がありません"
            return nil
        }
        do {
            return try exportService.export(filteredVideos, format: format)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
