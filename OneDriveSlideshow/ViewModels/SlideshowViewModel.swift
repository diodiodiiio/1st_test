import SwiftUI
import Combine

@MainActor
final class SlideshowViewModel: ObservableObject {
    @Published var images: [DriveItem] = []
    @Published var currentIndex: Int = 0
    @Published var currentImage: UIImage?
    @Published var nextImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPlaying = false
    @Published var settings = SlideshowSettings()

    private var timer: AnyCancellable?
    private var prefetchTask: Task<Void, Never>?
    private let authViewModel: AuthViewModel
    private let settingsKey = "SlideshowSettings"

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        loadSettings()
    }

    func loadImages(folderID: String?) async {
        guard let folderID else {
            errorMessage = "フォルダが選択されていません"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await authViewModel.validToken()
            let all = try await OneDriveAPIService.shared.listChildren(itemID: folderID, token: token)
            let imageItems = all.filter { $0.isImage }
            images = settings.shuffle ? imageItems.shuffled() : imageItems.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            currentIndex = 0
            await loadCurrentImage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSlideshow() {
        guard !images.isEmpty else { return }
        isPlaying = true
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn
        scheduleNext()
    }

    func stopSlideshow() {
        isPlaying = false
        timer?.cancel()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func togglePlayPause() {
        if isPlaying { stopSlideshow() } else { startSlideshow() }
    }

    func advance(by delta: Int) {
        guard !images.isEmpty else { return }
        timer?.cancel()
        currentIndex = (currentIndex + delta + images.count) % images.count
        Task { await loadCurrentImage() }
        if isPlaying { scheduleNext() }
    }

    private func scheduleNext() {
        timer?.cancel()
        timer = Just(())
            .delay(for: .seconds(settings.intervalSeconds), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    self.currentIndex = (self.currentIndex + 1) % self.images.count
                    await self.loadCurrentImage()
                    if self.isPlaying { self.scheduleNext() }
                }
            }
    }

    private func loadCurrentImage() async {
        guard !images.isEmpty else { return }
        let item = images[currentIndex]
        if let cached = ImageCacheService.shared.image(for: item.id) {
            currentImage = cached
        } else {
            currentImage = nil
            do {
                let token = try await authViewModel.validToken()
                let data = try await OneDriveAPIService.shared.downloadImageData(item: item, token: token)
                ImageCacheService.shared.store(data: data, for: item.id)
                currentImage = UIImage(data: data)
            } catch {
                errorMessage = "画像読み込み失敗: \(error.localizedDescription)"
            }
        }
        prefetchNext()
    }

    private func prefetchNext() {
        prefetchTask?.cancel()
        let nextIdx = (currentIndex + 1) % images.count
        guard nextIdx != currentIndex else { return }
        let item = images[nextIdx]
        guard !ImageCacheService.shared.isCached(itemID: item.id) else { return }
        prefetchTask = Task {
            guard let token = try? await authViewModel.validToken() else { return }
            guard let data = try? await OneDriveAPIService.shared.downloadImageData(item: item, token: token) else { return }
            ImageCacheService.shared.store(data: data, for: item.id)
        }
    }

    var currentItemName: String { images[safe: currentIndex]?.name ?? "" }
    var progress: String { images.isEmpty ? "" : "\(currentIndex + 1) / \(images.count)" }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let s = try? JSONDecoder().decode(SlideshowSettings.self, from: data) {
            settings = s
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
